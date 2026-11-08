pipeline {
    // 'any' означает "запускать на любом доступном узле, включая главный"
    agent any 
    
    environment {
        DOCKER_HUB_USER = 'vademk'
        DOCKER_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_NAME = 'app-canary'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build & Push Images') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', DOCKER_CREDENTIALS_ID) {
                        def backImage = docker.build("${DOCKER_HUB_USER}/crudback:${BUILD_NUMBER}", "-f php.Dockerfile .")
                        def dbImage = docker.build("${DOCKER_HUB_USER}/crudmysql:${BUILD_NUMBER}", "-f mysql.Dockerfile .")
                        backImage.push()
                        dbImage.push()
                    }
                }
            }
        }
        stage('Canary Deployment') {
            steps {
                sh 'docker stack deploy --with-registry-auth -c docker-compose_canary.yaml ${APP_NAME}'
                sh 'sleep 30'
            }
        }
        stage('Canary Testing') {
            steps {
                sh 'curl -f -s http://192.168.0.1:8081 || exit 1'
            }
        }
        stage('Promote to Production') {
            steps {
                sh 'docker stack deploy --with-registry-auth -c docker-compose.yaml app'
            }
        }
        stage('Cleanup Canary') {
            steps {
                sh 'docker stack rm ${APP_NAME} || true'
            }
        }
    }
    post {
        failure {
            echo "Pipeline failed! Rolling back canary stack."
            sh 'docker stack rm ${APP_NAME} || true'
        }
    }
}
