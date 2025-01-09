# Use an official OpenJDK runtime as a parent image
FROM openjdk:11-jre-slim

# Set the working directory
WORKDIR /app

# Copy the Spring Boot jar file
COPY target/*.jar app.jar

# Expose the port the app runs on
EXPOSE 8080

# Define the command to run the app
ENTRYPOINT ["java", "-jar", "app.jar"]
