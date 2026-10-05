pipeline {
    agent any

    environment {
        GITHUB_REPO = 'https://github.com/himanshu-sahu/devops-test.git'
        GIT_BRANCH = 'main'
        CREDENTIALS_ID = 'github-creds'
    }

    stages {
        stage('Checkout from GitHub') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${env.GIT_BRANCH}"]],
                    userRemoteConfigs: [[
                        url: env.GITHUB_REPO,
                        credentialsId: env.CREDENTIALS_ID
                    ]]
                ])
            }
        }

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
                    . .venv/bin/activate
                    pytest -q
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t aceest-fitness-gym .'
            }
        }
    }
}
