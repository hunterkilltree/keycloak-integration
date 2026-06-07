# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Cache dependencies first
COPY pom.xml .
COPY .mvn/ .mvn/
RUN mvn -B -q dependency:go-offline

# Build the application
COPY src/ src/
RUN mvn -B -q clean package -DskipTests

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app

# Non-root user for security
RUN groupadd -r app && useradd -r -g app app

COPY --from=build /app/target/keycloak-be-*.jar app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
