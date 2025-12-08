# apiFestivos/Dockerfile CORREGIDO:
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl
RUN addgroup -S appuser && adduser -S appuser -G appuser

# CRÍTICO: Copiar JAR correcto
COPY --from=build /app/presentacion/target/*.jar app.jar
RUN chown appuser:appuser app.jar
USER appuser

EXPOSE 8080
# CRÍTICO: Comando funcional
CMD ["java", "-jar", "app.jar"]
