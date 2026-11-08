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
                sh 'sleep 25'
            }
        }
        stage('Canary Testing') {
            steps {
                sh '''
                    echo "=== ПРОВЕРКА СТАТУСА СЕРВИСОВ ==="
                    docker service ps ${APP_NAME}_web-server --no-trunc || true
                    docker service ps ${APP_NAME}_db --no-trunc || true
                    
                    echo "=== ОЖИДАНИЕ ГОТОВНОСТИ CANARY (до 60 сек) ==="
                    ATTEMPT=1
                    while [ $ATTEMPT -le 12 ]; do
                        if curl -f -s http://192.168.0.1:8081 > /dev/null; then
                            echo "✅ УСПЕХ: Canary-версия работает и отвечает!"
                            exit 0
                        fi
                        echo "Попытка $ATTEMPT не удалась. Ждем 5 секунд..."
                        sleep 5
                        ATTEMPT=$((ATTEMPT + 1))
                    done
                    
                    echo "❌ ОШИБКА: Canary-сервис не ответил вовремя. Смотрим логи:"
                    docker service logs ${APP_NAME}_web-server --tail 30 || true
                    docker service logs ${APP_NAME}_db --tail 30 || true
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
