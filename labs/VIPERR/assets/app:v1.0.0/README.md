# Webinar App Demo App 1.0.0

A simple Go Gin web application has seen quite a transformation and is now "cloud native" and containerised.

Additionally, we are using some new tools such as Docker multi-stage build AND using our favourite version of Alpine as a base image.
This is to show how you can deliver images for scanning and secondly to see vulns from the OS level being introduced.

**Test**
docker container run --publish 8080:8080 app:v1.0.0
curl http://localhost:8080/ping