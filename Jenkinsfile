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
                sh 'sleep 30'
            }
        }
        stage('Canary Testing') {
            steps {
                sh '''
                    echo "Проверка доступности canary-версии..."
                    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
                        if curl -f -s http://192.168.0.1:8081 > /dev/null; then
                            echo "УСПЕХ: Canary работает!"
                            exit 0
                        fi
                        echo "Попытка $i не удалась, ждем 5 сек..."
                        sleep 5
                    done
                    echo "ОШИБКА: Canary не ответил за 60 секунд"
                    docker service logs ${APP_NAME}_web-server --tail 20 || true
                    exit 1
                '''
            }
        }
        // МЕНЯЕМ ПОРЯДОК: Сначала чистим canary, чтобы освободить порт 8081
        stage('Cleanup Canary') {
            steps {
                sh 'docker stack rm ${APP_NAME} || true'
                sh 'sleep 10' // Даем Swarm время на освобождение порта
            }
        }
        stage('Promote to Production') {
            steps {
                sh 'docker stack deploy --with-registry-auth -c docker-compose.yaml app'
            }
        }
    }
    post {
        failure {
            echo "Pipeline failed! Откат canary стека."
            sh 'docker stack rm ${APP_NAME} || true'
        }
    }
}
