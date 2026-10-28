FROM golang:1.24-alpine AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

FROM alpine:3.20 AS runtime

RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=build /out/api /app/api
EXPOSE 8080
# Runs as root: SQLite in WAL mode needs write access to the shared -shm file
# that the bot container (root) creates in ./data.
ENTRYPOINT ["/app/api"]
