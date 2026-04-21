FROM golang:1.25-alpine AS build

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o email-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /app/email-service /usr/local/bin/email-service
EXPOSE 8080
CMD ["email-service"]
