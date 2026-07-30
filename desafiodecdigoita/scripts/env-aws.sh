#!/bin/bash
# ==========================================
# Environment Variables - AWS (Produção)
# ==========================================
# Uso: source scripts/env-aws.sh
# ==========================================

export SERVER_PORT=8080

# ALB DNS da AWS
export ALB_DNS="transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com"

# API URL base
export API_URL="http://${ALB_DNS}"

# MongoDB host (sidecar no ECS - localhost)
export MONGODB_HOST="localhost"

# AWS
export AWS_DEFAULT_REGION="sa-east-1"

# SQS (AWS)
export SQS_QUEUE_URL="https://sqs.sa-east-1.amazonaws.com/219173034456/transaction-api_conta-bancaria-criada"
export SQS_DLQ_URL="https://sqs.sa-east-1.amazonaws.com/219173034456/transaction-api_conta-bancaria-criada-dlq"
export SQS_POLL_INTERVAL="5000"

# Security (carregado do AWS Secrets Manager)
export JWT_EXPIRATION="86400"

# CloudWatch
export CLOUDWATCH_ENABLED="true"
export CLOUDWATCH_NAMESPACE="TransactionAPI"

# S3 Logs
export S3_LOG_BUCKET="transaction-api-logs-219173034456"
export SERVICE_NAME="transaction-api"

# Logging
export LOG_LEVEL="INFO"
export LOG_LEVEL_MONGODB="WARN"

echo "✅ Environment: AWS"
echo "   API URL:      ${API_URL}"
echo "   SQS Queue:    ${SQS_QUEUE_URL}"
echo "   CloudWatch:   enabled"
echo "   S3 Logs:      s3://${S3_LOG_BUCKET}"
echo ""
echo "📋 Comandos rápidos:"
echo ""
echo "   # Gerar token JWT:"
echo "   curl -s -X POST ${API_URL}/api/v1/auth/token \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"client_id\":\"transaction-api-client\",\"client_secret\":\"AxIp+2lLcgdYV8oVYrC15w==\"}'"
echo ""
echo "   # Seed de contas:"
echo "   ./scripts/seed-accounts.sh"
echo ""
echo "   # Verificar health:"
echo "   curl -s ${API_URL}/actuator/health | jq ."