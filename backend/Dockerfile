# syntax=docker/dockerfile:1
FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /app
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn dependency:go-offline -q
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn clean package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
USER spring
EXPOSE 8080
# Limite de heap compatível com VPS 4GB (3 containers): 512m é suficiente para Spring Boot
ENTRYPOINT ["java", "-Xmx512m", "-Xms128m", "-jar", "app.jar"]
