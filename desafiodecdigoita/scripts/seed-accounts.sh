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

# Usa credenciais AWS do ambiente ou fallback para LocalStack
AWS_KEY="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET="${AWS_SECRET_ACCESS_KEY:-test}"

# Lê o host do MongoDB do Secrets Manager do LocalStack
echo "📖 Lendo configuração do MongoDB do Secrets Manager..."
MONGODB_SECRET=$(AWS_ACCESS_KEY_ID="$AWS_KEY" AWS_SECRET_ACCESS_KEY="$AWS_SECRET" aws --endpoint-url=http://localhost:4566 --region sa-east-1 secretsmanager get-secret-value --secret-id transaction-api/mongodb --query SecretString --output text 2>/dev/null || echo '{"uri":"mongodb://admin:admin123@localhost:27017/transaction_db?authSource=admin"}')
MONGODB_URI=$(echo "$MONGODB_SECRET" | jq -r '.uri')
echo "   MongoDB URI: $MONGODB_URI"
echo ""

# Gera 10 contas de teste
for i in $(seq 1 10); do
    ACCOUNT_ID=$(uuidgen)
    OWNER_ID=$(uuidgen)
    CREATED_AT=$(date +%s)

    AWS_ACCESS_KEY_ID="$AWS_KEY" AWS_SECRET_ACCESS_KEY="$AWS_SECRET" aws --endpoint-url=http://localhost:4566 \
        --region sa-east-1 \
        sqs send-message \
        --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
        --message-body "{\"account\":{\"id\":\"$ACCOUNT_ID\",\"owner\":\"$OWNER_ID\",\"created_at\":\"$CREATED_AT\",\"status\":\"ENABLED\"}}"

    echo "   ✅ Conta $i: $ACCOUNT_ID"
done

echo ""
echo "✅ 10 contas de teste enviadas para SQS!"
echo "   Fila: http://localhost:4566/000000000000/conta-bancaria-criada"
echo "   MongoDB: $MONGODB_URI"