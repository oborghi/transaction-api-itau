#!/bin/bash
# ==========================================
# LocalStack Init Script
# ==========================================
# Cria filas SQS, bucket S3 e secrets no AWS Secrets Manager.
#
# Funciona em dois cenários:
#   1. Dentro do container Docker (via awslocal)
#   2. Localmente (via aws --endpoint-url)
#
# Uso:
#   ./scripts/init-localstack.sh                    # usa aws --endpoint-url (local)
#   ./scripts/init-localstack.sh --docker           # usa awslocal (dentro do container)
# ==========================================

set -e

# Detecta modo de execução automaticamente
# - Se awslocal existe no PATH, está dentro do container LocalStack
# - Caso contrário, usa aws CLI com endpoint
if command -v awslocal &> /dev/null; then
    AWS_CMD="awslocal"
    echo "🚀 LocalStack Init Script (modo Docker - awslocal detectado)"
else
    ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
    AWS_CMD="aws --endpoint-url=$ENDPOINT"
    echo "🚀 LocalStack Init Script (modo local - endpoint: $ENDPOINT)"
fi

echo ""

# ==========================================
# 1. Criar filas SQS
# ==========================================
echo "📨 Criando filas SQS..."
$AWS_CMD sqs create-queue --queue-name conta-bancaria-criada --region sa-east-1 2>/dev/null || true
$AWS_CMD sqs create-queue --queue-name conta-bancaria-criada-dlq --region sa-east-1 2>/dev/null || true
echo "   ✅ Filas SQS criadas"

# ==========================================
# 2. Criar bucket S3
# ==========================================
echo ""
echo "📦 Criando bucket S3..."
$AWS_CMD s3 mb s3://transaction-api_logs --region sa-east-1 2>/dev/null || true
echo "   ✅ Bucket S3 criado"

# ==========================================
# 3. Criar secrets no AWS Secrets Manager
# ==========================================
echo ""
echo "🔐 Criando secrets no AWS Secrets Manager..."

# MongoDB host (usa variável de ambiente ou default)
MONGODB_HOST="${MONGODB_HOST:-mongodb}"

# MongoDB secret
$AWS_CMD secretsmanager create-secret \
    --name transaction-api/mongodb \
    --description "MongoDB connection credentials" \
    --secret-string "{\"uri\":\"mongodb://admin:admin123@${MONGODB_HOST}:27017/transaction_db?authSource=admin\",\"username\":\"admin\",\"password\":\"admin123\"}" 2>/dev/null || \
$AWS_CMD secretsmanager put-secret-value \
    --secret-id transaction-api/mongodb \
    --secret-string "{\"uri\":\"mongodb://admin:admin123@${MONGODB_HOST}:27017/transaction_db?authSource=admin\",\"username\":\"admin\",\"password\":\"admin123\"}"
echo "   ✅ MongoDB secret"

# JWT secret
$AWS_CMD secretsmanager create-secret \
    --name transaction-api/jwt \
    --description "JWT signing key and configuration" \
    --secret-string '{"secret":"MyDefaultSecretKeyForDevelopmentOnly2024!","issuer":"transaction-api"}' 2>/dev/null || \
$AWS_CMD secretsmanager put-secret-value \
    --secret-id transaction-api/jwt \
    --secret-string '{"secret":"MyDefaultSecretKeyForDevelopmentOnly2024!","issuer":"transaction-api"}'
echo "   ✅ JWT secret"

# AWS/SQS secret
$AWS_CMD secretsmanager create-secret \
    --name transaction-api/sqs \
    --description "SQS configuration" \
    --secret-string '{"region":"sa-east-1","endpoint":"http://localstack:4566"}' 2>/dev/null || \
$AWS_CMD secretsmanager put-secret-value \
    --secret-id transaction-api/sqs \
    --secret-string '{"region":"sa-east-1","endpoint":"http://localstack:4566"}'
echo "   ✅ AWS/SQS secret"

# API credentials
$AWS_CMD secretsmanager create-secret \
    --name transaction-api/credentials \
    --description "API client credentials" \
    --secret-string '{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}' 2>/dev/null || \
$AWS_CMD secretsmanager put-secret-value \
    --secret-id transaction-api/credentials \
    --secret-string '{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'
echo "   ✅ Credentials secret"

echo ""
echo "✅ LocalStack init completed successfully!"