pipeline {
    agent any

    environment {
        GITHUB_REPO = 'https://github.com/<your-github-username>/<your-repo-name>.git'
        GIT_BRANCH = 'main'
        CREDENTIALS_ID = 'github-creds'
    }

    stages {
        stage('Checkout from GitHub') {
            steps {
                git branch: env.GIT_BRANCH,
                    credentialsId: env.CREDENTIALS_ID,
                    url: env.GITHUB_REPO
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'python3 -m pip install --upgrade pip'
                sh 'pip install -r requirements.txt'
            }
        }

        stage('Run Tests') {
            steps {
                sh 'pytest -q'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t aceest-fitness-gym .'
            }
        }
    }
}
