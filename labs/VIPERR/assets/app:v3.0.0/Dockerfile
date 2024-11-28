FROM golang:1.22-alpine AS build-stage
WORKDIR /go/src/go-app
COPY app.go .
COPY go.mod go.sum ./
RUN go mod tidy
RUN go mod download
RUN go build -o app .

FROM base:v1.0.0

# copy the binary from the `build-stage`
COPY --from=build-stage /go/src/go-app/app /bin

HEALTHCHECK --interval=5m --start-period=3m --start-interval=10s \
  CMD curl -f http://localhost:8080/ping || exit 1

CMD app