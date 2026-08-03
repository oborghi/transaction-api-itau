# Stage 1: Build
FROM maven:3.9.6-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY transaction-domain/pom.xml transaction-domain/
COPY transaction-application/pom.xml transaction-application/
COPY transaction-infrastructure/pom.xml transaction-infrastructure/
COPY transaction-api/pom.xml transaction-api/
RUN mvn dependency:go-offline -B
COPY . .
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN apk add --no-cache curl bash
WORKDIR /app

# Copy application classes (non-repackaged jar)
COPY --from=builder /app/transaction-api/target/transaction-api-1.0.0-SNAPSHOT.jar app.jar

# Copy dependencies to libs/ directory
COPY --from=builder /app/transaction-api/target/libs/ libs/

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# Create data directories for volumes
RUN mkdir -p /app/data

USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["/app/docker-entrypoint.sh"]