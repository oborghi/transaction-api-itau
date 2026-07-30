#!/bin/bash
# ==========================================
# Environment Variables - Local Development
# ==========================================
# Uso: source scripts/env-local.sh
# ==========================================

export SERVER_PORT=8080

# MongoDB host (varia conforme o ambiente)
export MONGODB_HOST="localhost"

# MongoDB URI (usa MONGODB_HOST)
export SPRING_DATA_MONGODB_URI="mongodb://admin:admin123@${MONGODB_HOST}:27017/transaction_db?authSource=admin"

# AWS (LocalStack)
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_DEFAULT_REGION="sa-east-1"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# SQS (LocalStack)
export SQS_QUEUE_URL="http://localhost:4566/000000000000/conta-bancaria-criada"
export SQS_DLQ_URL="http://localhost:4566/000000000000/conta-bancaria-criada-dlq"
export SQS_POLL_INTERVAL="5000"

# Security (loaded exclusively from AWS Secrets Manager via LocalStack)
export JWT_EXPIRATION="86400"

# CloudWatch (via LocalStack)
export CLOUDWATCH_ENABLED="true"
export CLOUDWATCH_NAMESPACE="TransactionAPI"

# S3 Logs (via LocalStack)
export S3_LOG_BUCKET="transaction-api_logs"
export SERVICE_NAME="transaction-api"

# Logging
export LOG_LEVEL="DEBUG"
export LOG_LEVEL_MONGODB="DEBUG"

echo "✅ Environment: LOCAL"
echo "   DocumentDB (LocalStack): localhost:27017"
echo "   LocalStack: localhost:4566"
echo "   CloudWatch: enabled (via LocalStack)"
echo "   S3 Logs: s3://transaction-api_logs"
