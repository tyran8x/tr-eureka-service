# Stage 1: Build Stage
FROM maven:3.9.8-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY pom.xml .
COPY settings.xml .
RUN mvn -s settings.xml dependency:go-offline
COPY src ./src
RUN mvn -s settings.xml clean package -DskipTests

# Stage 2: Create minimal Java runtime with JLink
FROM eclipse-temurin:21-jdk-alpine AS jlink
RUN $JAVA_HOME/bin/jlink \
    --module-path $JAVA_HOME/jmods \
    --add-modules java.base,java.logging,java.xml,java.naming,java.sql,java.management,java.instrument,jdk.unsupported,java.desktop,java.security.jgss \
    --output /javaruntime \
    --compress=2 --no-header-files --no-man-pages

# Stage 3: Final Stage
FROM alpine:latest AS final
WORKDIR /app
COPY --from=jlink /javaruntime /opt/java-minimal
ENV PATH="/opt/java-minimal/bin:$PATH"
COPY --from=build /app/target/*.jar tr-eureka-service.jar

EXPOSE 8061
ENTRYPOINT ["java", "-jar", "tr-eureka-service.jar"]

