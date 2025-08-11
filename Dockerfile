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

RUN adduser -D -h /home/appuser -s /bin/sh appuser
RUN mkdir -p /opt/logs && chown -R appuser:appuser /opt/logs $APP_HOME
RUN apk update && apk add --no-cache curl

COPY --from=builder --chown=appuser:appuser /app/target/extracted/dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/application/ ./

EXPOSE 8061
USER appuser
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
