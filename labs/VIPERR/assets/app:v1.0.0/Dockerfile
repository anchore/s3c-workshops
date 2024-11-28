# first stage does the building
# for UX purposes, I'm naming this stage `build-stage`

FROM golang:1.20-alpine AS build-stage
WORKDIR /go/src/go-app
COPY app.go .
COPY go.mod go.sum ./
RUN go mod tidy
RUN go mod download
RUN go build -o app .

# starting second stage
FROM alpine:3.10.4

# copy the binary from the `build-stage`
COPY --from=build-stage /go/src/go-app/app /bin

CMD app