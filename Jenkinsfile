pipeline {
    agent { label 'docker-agent' }
    
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
                sh 'sleep 20' // Даем Swarm время на создание сети и контейнеров
            }
        }
        stage('Canary Testing') {
            steps {
                // Умная проверка с повторными попытками (до 50 секунд)
                sh '''
                    echo "Waiting for canary service to be ready..."
                    for i in {1..10}; do
                        if curl -f -s http://192.168.0.1:8081 > /dev/null; then
                            echo "SUCCESS: Canary is UP and responding!"
                            exit 0
                        fi
                        echo "Attempt $i failed, waiting 5 seconds..."
                        sleep 5
                    done
                    echo "ERROR: Canary service did not respond in time"
                    exit 1
                '''
            }
        }
        stage('Promote to Production') {
            steps {
                script {
                    echo "Canary successful! Updating main stack..."
                    sh 'docker stack deploy --with-registry-auth -c docker-compose.yaml app'
                }
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
            echo "Pipeline failed! Rolling back or keeping stable version."
            sh 'docker stack rm ${APP_NAME} || true'
        }
    }
}
