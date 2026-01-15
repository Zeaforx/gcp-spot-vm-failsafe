# Builder Stage
FROM golang:1.21 as builder

WORKDIR /app

# Initialize module if not present (simulated since we run go mod init before build usually)
COPY go.mod ./
# COPY go.sum ./ # No dependencies yet
# RUN go mod download

COPY . .

# Build binary
# CGO_ENABLED=0 for static binary
RUN CGO_ENABLED=0 GOOS=linux go build -o server main.go

# Runtime Stage
# Use distroless for security and minimal size
FROM gcr.io/distroless/static-debian12

WORKDIR /

COPY --from=builder /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
