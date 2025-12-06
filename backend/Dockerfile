# AWS Lambda Web Adapter使用
FROM public.ecr.aws/docker/library/golang:1.24-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage
FROM public.ecr.aws/awsguru/aws-lambda-adapter:0.8.1

# Copy the binary from builder
COPY --from=builder /app/main /var/task/main

# Lambda Web Adapter の設定
ENV PORT=8080
ENV AWS_LWA_INVOKE_MODE=response_stream

# Run the application
CMD ["/var/task/main"]
