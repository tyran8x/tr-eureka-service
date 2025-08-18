# STAGE 1: BUILD APPLICATION
FROM maven:3.9.11-eclipse-temurin-21-alpine AS builder

WORKDIR /app
COPY settings.xml pom.xml ./

# Tải dependency về trước để tận dụng cache
RUN mvn -B -s settings.xml dependency:go-offline dependency:resolve-plugins

# Copy mã nguồn
COPY src ./src

# Build fat JAR VÀ trích xuất layers.
# Lệnh này sẽ hoạt động sau khi pom.xml được sửa.
RUN mvn -B -s settings.xml package spring-boot:repackage -DskipTests && \
    java -Djarmode=tools -jar target/*.jar extract --layers --launcher --destination target/extracted


# STAGE 2: CREATE FINAL RUNTIME IMAGE
FROM eclipse-temurin:21-jre-alpine

ENV APP_HOME=/app \
    TZ=Asia/Ho_Chi_Minh

WORKDIR $APP_HOME

# Tạo user, cài đặt các gói cần thiết và tạo thư mục trong MỘT LỆNH RUN DUY NHẤT
# Điều này giảm số lượng layer, làm cho image nhỏ hơn và build nhanh hơn.
RUN adduser -D -h ${APP_HOME} -s /bin/sh appuser && \
    apk update && apk add --no-cache curl && \
    mkdir -p /opt/logs && \
    chown -R appuser:appuser ${APP_HOME} /opt/logs

COPY --from=builder --chown=appuser:appuser /app/target/extracted/dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/application/ ./

# Mở port cho ứng dụng
EXPOSE 8061

# Thêm Health Check để Docker/Kubernetes biết ứng dụng có thực sự khỏe mạnh không
# Yêu cầu phải có Spring Boot Actuator và endpoint /actuator/health
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8061/actuator/health || exit 1

# Chuyển sang user không phải root
USER appuser

# Lệnh khởi động ứng dụng
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
