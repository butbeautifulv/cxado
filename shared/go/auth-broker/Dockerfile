# syntax=docker/dockerfile:1

FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /auth-broker ./cmd/broker

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=build /auth-broker /usr/local/bin/auth-broker
USER nobody
EXPOSE 8080 9090
ENTRYPOINT ["auth-broker"]
