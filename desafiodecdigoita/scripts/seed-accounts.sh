#!/bin/bash
set -e

echo "🌱 Populando SQS com contas de teste..."
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

# Gera 10 contas de teste
for i in $(seq 1 10); do
    ACCOUNT_ID=$(uuidgen)
    OWNER_ID=$(uuidgen)
    CREATED_AT=$(date +%s)

    aws --endpoint-url=http://localhost:4566 \
        --region sa-east-1 \
        sqs send-message \
        --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
        --message-body "{\"account\":{\"id\":\"$ACCOUNT_ID\",\"owner\":\"$OWNER_ID\",\"created_at\":\"$CREATED_AT\",\"status\":\"ENABLED\"}}"

    echo "   ✅ Conta $i: $ACCOUNT_ID"
done

echo ""
echo "✅ 10 contas de teste enviadas para SQS!"
echo "   Fila: http://localhost:4566/000000000000/conta-bancaria-criada"