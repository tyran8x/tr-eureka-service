FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

WORKDIR /app
COPY settings.xml pom.xml ./

RUN mvn -B -s settings.xml dependency:go-offline dependency:resolve-plugins
COPY src ./src
RUN mvn -B -s settings.xml package -DskipTests spring-boot:repackage \
 && java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# -------- RUNTIME --------
FROM eclipse-temurin:21-jre-alpine
ENV APP_HOME=/app \
    TZ=Asia/Ho_Chi_Minh
WORKDIR $APP_HOME

# Tạo user non-root có home (tránh lỗi ghi file tạm, tốt cho Spring)
RUN adduser -D -h /home/appuser -s /bin/sh appuser

# Tạo thư mục log theo chuẩn, cấp quyền cho appuser (rất quan trọng!)
RUN mkdir -p /opt/logs && chown -R appuser:appuser /opt/logs $APP_HOME

RUN apk update && apk add --no-cache curl

# Copy layers Spring Boot
COPY --from=builder --chown=appuser:appuser /app/target/extracted/dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/application/ ./

EXPOSE 8061
USER appuser

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
