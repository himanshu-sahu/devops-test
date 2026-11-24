pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOYMENT_STRATEGY',
            choices: ['rolling', 'blue-green', 'canary', 'shadow', 'a-b', 'rollback'],
            description: 'Kubernetes deployment strategy'
        )
        booleanParam(
            name: 'ROLLBACK_ON_FAILURE',
            defaultValue: true,
            description: 'Automatically return to the last stable deployment if verification fails'
        )
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        PYTHONPATH = "${WORKSPACE}"
    }

    stages {
        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    python -m pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    pwd
                    ls -la
                    . .venv/bin/activate
                    python -m pytest -q
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withCredentials([string(credentialsId: 'sonar-qube-token', variable: 'SONAR_TOKEN')]) {
                        withSonarQubeEnv('SonarQube') {
                            sh "${scannerHome}/bin/sonar-scanner -Dsonar.token=${SONAR_TOKEN}"
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker --version
                    docker build -t aceest-fitness-gym .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKERHUB_USERNAME',
                    passwordVariable: 'DOCKERHUB_PASSWORD'
                )]) {
                    sh '''
                        set -eu
                        export DOCKER_CONFIG="$(mktemp -d)"
                        trap 'rm -rf "$DOCKER_CONFIG"' EXIT

                        IMAGE_REPOSITORY='docker.io/jaarrviss/devops-test'
                        printf '%s' "$DOCKERHUB_PASSWORD" | docker login docker.io \
                            --username "$DOCKERHUB_USERNAME" --password-stdin
                        docker tag aceest-fitness-gym "$IMAGE_REPOSITORY:latest"
                        docker tag aceest-fitness-gym "$IMAGE_REPOSITORY:$BUILD_NUMBER"
                        docker push "$IMAGE_REPOSITORY:latest"
                        docker push "$IMAGE_REPOSITORY:$BUILD_NUMBER"
                    '''
                }
            }
        }

        stage('Deploy Docker Container') {
            steps {
                sh '''
                    if docker container inspect aceest-fitness-gym >/dev/null 2>&1; then
                        docker rm -f aceest-fitness-gym
                    fi
                    docker run -d --name aceest-fitness-gym --restart unless-stopped -p 5001:5000 aceest-fitness-gym
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'minikube-kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl cluster-info
                        ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE}" \
                        ./scripts/kubernetes-deploy.sh "${DEPLOYMENT_STRATEGY}"
                    '''
                }
            }
        }
    }
}
