#!/bin/bash
# ==========================================
# Environment Variables - AWS Production (EKS)
# ==========================================
# Uso: source scripts/env-aws.sh
# ==========================================
# Em produção AWS, os secrets vêm do AWS Secrets Manager,
# não de variáveis de ambiente. Este script define apenas
# variáveis não-sensíveis para configuração.
# ==========================================

export SERVER_PORT=8080

# MongoDB (DocumentDB via Secrets Manager)
# SPRING_DATA_MONGODB_URI será carregado do Secrets Manager
export SPRING_DATA_MONGODB_URI=""

# AWS (real AWS, não LocalStack)
export AWS_ENDPOINT_URL=""
export AWS_DEFAULT_REGION="sa-east-1"
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""

# SQS (AWS real)
# SQS_QUEUE_URL e SQS_DLQ_URL serão carregados do Secrets Manager
export SQS_QUEUE_URL=""
export SQS_DLQ_URL=""
export SQS_POLL_INTERVAL="5000"

# Security (carregado do Secrets Manager)
export JWT_SECRET=""
export JWT_EXPIRATION="86400"
export API_CLIENT_ID=""
export API_CLIENT_SECRET=""
export API_READONLY_ID=""
export API_READONLY_SECRET=""

# Secrets Manager (enabled for AWS)
export AWS_SECRETS_ENABLED="true"

# Observability (CloudWatch)
export CLOUDWATCH_ENABLED="true"
export CLOUDWATCH_NAMESPACE="TransactionAPI"
export ACTUATOR_EXPOSURE="health,info,metrics"

# S3 Logs (AWS real)
export S3_LOG_BUCKET="${S3_LOG_BUCKET:-transaction-api-logs}"
export SERVICE_NAME="transaction-api"

# Logging
export LOG_LEVEL="INFO"
export LOG_LEVEL_MONGODB="WARN"

echo "✅ Environment: AWS"
echo "   Region: ${AWS_DEFAULT_REGION}"
echo "   Secrets Manager: enabled"
echo "   CloudWatch: enabled"
echo "   S3 Logs: s3://${S3_LOG_BUCKET}"
