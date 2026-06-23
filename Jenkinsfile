pipeline {
    agent any

    environment {
        // Hãy thay tên tài khoản Docker Hub thật của bạn vào đây
        DOCKER_HUB_USER = 'truongduoc'
        AWS_SERVER_IP   = '13.239.138.175'
    }

    stages {
        stage('1. Chép mã nguồn từ Git') {
            steps {
                checkout scm
            }
        }

        stage('2. Biên dịch ứng dụng Java') {
            steps {
                // Chạy lệnh Maven đóng gói file .jar (bỏ qua test để tăng tốc độ)
                sh 'chmod +x mvnw'
                sh './mvnw clean package -DskipTests'
            }
        }

        stage('3. Đóng gói & Đẩy Image lên Docker Hub') {
            steps {
                script {
                    // Gọi két sắt thông tin tài khoản Docker Hub
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                        sh "docker build -t ${DOCKER_HUB_USER}/spring-petclinic:latest ."
                        sh "echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin"
                        sh "docker push ${DOCKER_HUB_USER}/spring-petclinic:latest"
                    }
                }
            }
        }

        stage('4. Triển khai tự động lên AWS EC2') {
            steps {
                script {
                    // Gọi két sắt chứa chìa khóa SSH EC2 mà bạn vừa cấu hình ở Bước 1
                    sshagent(credentials: ['aws-ec2-key']) {
                        // Tạo thư mục chứa dự án trên server AWS
                        sh "ssh -o StrictHostKeyChecking=no ubuntu@${AWS_SERVER_IP} 'mkdir -p ~/app'"
                        
                        // Copy file cấu hình docker-compose.prod.yml lên server AWS
                        sh "scp -o StrictHostKeyChecking=no docker-compose.prod.yml ubuntu@${AWS_SERVER_IP}:~/app/docker-compose.yml"
                        
                        // Ra lệnh cho server AWS kéo Image mới nhất về và khởi chạy ngầm
                        sh """
                            ssh -o StrictHostKeyChecking=no ubuntu@${AWS_SERVER_IP} '
                                cd ~/app &&
                                export DOCKER_HUB_USER=${DOCKER_HUB_USER} &&
                                docker-compose pull &&
                                docker-compose up -d
                            '
                        """
                    }
                }
            }
        }
    }
}