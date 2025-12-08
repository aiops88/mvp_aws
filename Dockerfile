# Stage 1: Build the application
FROM maven:3.8.6-openjdk-17-slim AS build
WORKDIR /app
# Copia el archivo de configuración de Maven y el código fuente
COPY pom.xml .
COPY src ./src
# Compila la aplicación, saltando los tests para un build rápido
RUN mvn clean package -DskipTests

# Stage 2: Create the final, lightweight runtime image
# Usamos una imagen slim de OpenJDK para reducir el tamaño de la imagen final
FROM openjdk:17-jdk-slim
WORKDIR /app
# Copia el JAR compilado desde la etapa de construcción. Asume que el JAR se llama 'app.jar' o similar.
COPY --from=build /app/target/*.jar app.jar
# App Runner requiere que la aplicación escuche en el puerto 8080 por defecto
EXPOSE 8080
# Comando para ejecutar la aplicación
ENTRYPOINT ["java", "-jar", "app.jar"]