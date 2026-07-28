#!/bin/bash
set -e

echo "📨 Verificando fila SQS..."
echo ""

# Verifica AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale o AWS CLI."
    exit 1
fi

# Verifica se LocalStack está rodando
if ! curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack não está rodando. Execute: docker compose up -d localstack"
    exit 1
fi

echo "📋 Fila principal (conta-bancaria-criada):"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible 2>/dev/null || echo "   Fila não encontrada"

echo ""
echo "📋 Fila DLQ (conta-bancaria-criada-dlq):"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada-dlq \
    --attribute-names ApproximateNumberOfMessages 2>/dev/null || echo "   Fila não encontrada"

echo ""
echo "📋 Últimas 5 mensagens da fila principal:"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs receive-message \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
    --max-number-of-messages 5 2>/dev/null || echo "   Nenhuma mensagem"