FROM openjdk:17

# Update
# Install Java
ADD ./*/target/*.jar spring-mvc.jar

EXPOSE 8080

CMD java -jar spring-mvc.jar
