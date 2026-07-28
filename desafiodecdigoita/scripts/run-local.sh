#!/bin/bash
set -e

echo "🚀 Iniciando ambiente local..."
echo "   - LocalStack (SQS)"
echo "   - MongoDB"
echo "   - Transaction API"
echo ""

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# Criar pastas de dados (volumes do host)
mkdir -p data/{mongodb,prometheus,loki,grafana,vault,consul}

# Para containers anteriores
docker compose down -v 2>/dev/null || true

# Sobe todos os serviços
docker compose up -d --build

echo ""
echo "⏳ Aguardando serviços ficarem saudáveis..."
echo ""

# Aguarda healthcheck da API
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://127.0.0.1:8080/actuator/health > /dev/null 2>&1; then
        echo "✅ API está rodando em http://127.0.0.1:8080"
        echo "   - Swagger UI: http://127.0.0.1:8080/swagger-ui.html"
        echo "   - Health Check: http://127.0.0.1:8080/actuator/health"
        echo ""
        echo "📋 Para gerar um token de autenticação:"
        echo '   curl -X POST http://127.0.0.1:8080/api/v1/auth/token \'
        echo '     -H "Content-Type: application/json" \'
        echo '     -d '"'"'{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'"'"''
        echo ""
        echo "📋 Para verificar a fila SQS:"
        echo "   ./scripts/check-queue.sh"
        echo ""
        echo "📋 Para popular contas de teste:"
        echo "   ./scripts/seed-accounts.sh"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs: docker compose logs transaction-api"
exit 1