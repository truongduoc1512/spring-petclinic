# Stage 1: Build ứng dụng bằng Maven
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app

# Copy file cấu hình pom.xml và source code vào container
COPY pom.xml .
COPY src ./src

# Tiến hành build file .jar, bỏ qua chạy thử unit test để đẩy nhanh tốc độ
RUN mvn clean package -DskipTests

# Stage 2: Chạy ứng dụng với JRE tinh gọn
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy file .jar đã được tạo ở stage 1 sang stage 2
COPY --from=build /app/target/*.jar app.jar

# Khai báo port ứng dụng sẽ lắng nghe bên trong container
EXPOSE 8080

# Lệnh để chạy ứng dụng Spring Boot khi container khởi động
ENTRYPOINT ["java", "-jar", "app.jar"]