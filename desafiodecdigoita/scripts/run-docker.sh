#!/bin/bash
set -e

# ==========================================
# Transaction API - Docker Profile
# ==========================================
# Roda toda a aplicação em containers Docker:
#   - LocalStack (SQS)
#   - MongoDB
#   - Vault (Secrets)
#   - Consul (Config)
#   - Transaction API (Spring Boot)
#   - Prometheus, Grafana, Jaeger, Loki (Observability)
#
# Uso: ./scripts/run-docker.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "🐳 Iniciando ambiente Docker..."
echo "   - LocalStack (SQS)"
echo "   - MongoDB"
echo "   - Vault (Secrets)"
echo "   - Consul (Config)"
echo "   - Transaction API"
echo "   - Prometheus / Grafana / Jaeger / Loki"
echo ""

# ==========================================
# 1. Verificar pré-requisitos
# ==========================================
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# ==========================================
# 2. Parar serviços anteriores via stop-all.sh
# ==========================================
echo "🛑 Parando serviços anteriores..."
bash "$SCRIPT_DIR/stop-all.sh"

# Criar pastas de dados
mkdir -p data/{mongodb,prometheus,loki,grafana,vault,consul}

echo "🧹 Limpando dados anteriores..."
rm -rf data/consul/* data/mongodb/* data/prometheus/* data/loki/* data/grafana/* data/vault/* 2>/dev/null || true

# ==========================================
# 3. Subir infraestrutura (Vault, MongoDB, LocalStack, Consul)
# ==========================================
echo "📦 Subindo infraestrutura..."
docker compose up -d localstack mongodb vault consul

# ==========================================
# 4. Aguardar Vault ficar saudável
# ==========================================
echo ""
echo "⏳ Aguardando Vault ficar saudável..."

MAX_RETRIES=20
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://127.0.0.1:8200/v1/sys/health > /dev/null 2>&1; then
        echo "✅ Vault está rodando em http://127.0.0.1:8200"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 3
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Vault não ficou saudável após $MAX_RETRIES tentativas."
    exit 1
fi

# ==========================================
# 5. Inicializar filas SQS no LocalStack
# ==========================================
echo ""
echo "📨 Inicializando filas SQS no LocalStack..."

# Aguarda LocalStack estar pronto
sleep 3

docker exec localstack aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada 2>/dev/null || true
docker exec localstack aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada-dlq 2>/dev/null || true
echo "   ✅ Filas SQS criadas"

# ==========================================
# 6. Popula Vault com secrets
# ==========================================
echo ""
echo "🔐 Populando Vault com secrets..."

sleep 2

# Vault CLI via docker exec precisa de VAULT_ADDR e VAULT_TOKEN
VAULT_ENV="-e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root-token"

# Enable KV secrets engine (pode já estar habilitado em dev mode)
docker exec $VAULT_ENV vault vault secrets enable -path=secret kv-v2 2>/dev/null || true

# MongoDB secret
docker exec $VAULT_ENV vault vault kv put secret/transaction-api/mongodb \
  uri="mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin" \
  username="admin" \
  password="admin123"
echo "   ✅ MongoDB secret"

# JWT secret
docker exec $VAULT_ENV vault vault kv put secret/transaction-api/jwt \
  secret="MyDefaultSecretKeyForDevelopmentOnly2024!" \
  issuer="transaction-api"
echo "   ✅ JWT secret"

# AWS/SQS secret
docker exec $VAULT_ENV vault vault kv put secret/transaction-api/sqs \
  access_key="test" \
  secret_key="test" \
  region="sa-east-1" \
  endpoint="http://localstack:4566"
echo "   ✅ AWS/SQS secret"

# API credentials
docker exec $VAULT_ENV vault vault kv put secret/transaction-api/credentials \
  client_id="transaction-api-client" \
  client_secret="super-secret-key-123" \
  readonly_id="transaction-api-readonly" \
  readonly_secret="super-secret-key-123"
echo "   ✅ Credentials secret"

echo ""
echo "✅ Todos os secrets populados no Vault!"
echo "   Vault UI: http://localhost:8200 (token: root-token)"

# ==========================================
# 7. Popula Consul com configs
# ==========================================
echo ""
echo "🗄️ Populando Consul com configs..."

docker exec consul consul kv put transaction-api/config/mongodb-uri "mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin"
docker exec consul consul kv put transaction-api/config/jwt-secret "MyDefaultSecretKeyForDevelopmentOnly2024!"
docker exec consul consul kv put transaction-api/config/jwt-expiration "86400"
docker exec consul consul kv put transaction-api/config/sqs-endpoint "http://localstack:4566"
docker exec consul consul kv put transaction-api/config/sqs-queue "conta-bancaria-criada"
docker exec consul consul kv put transaction-api/config/dlq-queue "conta-bancaria-criada-dlq"
docker exec consul consul kv put transaction-api/config/circuit-breaker-threshold "50"
docker exec consul consul kv put transaction-api/config/dlq-reprocessor-interval "PT5M"
docker exec consul consul kv put transaction-api/config/prometheus-enabled "true"
docker exec consul consul kv put transaction-api/config/otel-enabled "true"

echo "   ✅ Consul configs populados!"
echo "   Consul UI: http://localhost:8500"

# ==========================================
# 8. Subir aplicação e observabilidade
# ==========================================
echo ""
echo "🚀 Subindo Transaction API + Observability..."
docker compose up -d --build transaction-api prometheus jaeger loki grafana

# ==========================================
# 9. Aguardar API ficar saudável
# ==========================================
echo ""
echo "⏳ Aguardando API ficar saudável..."

MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://127.0.0.1:8080/actuator/health > /dev/null 2>&1; then
        echo ""
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
        echo ""
        echo "📋 Vault UI: http://localhost:8200 (token: root-token)"
        echo "📋 Consul UI: http://localhost:8500"
        echo ""
        echo "📊 Observability:"
        echo "   - Grafana:    http://localhost:3000  (admin / admin123)"
        echo "   - Prometheus: http://localhost:9090"
        echo "   - Jaeger:     http://localhost:16686"
        echo "   - Loki:       http://localhost:3100"
        echo ""

        # Carrega dashboards do Grafana via API
        echo "📊 Carregando dashboards Grafana..."
        sleep 5
        for f in observability/grafana/dashboards/*.json; do
            if [ -f "$f" ]; then
                curl -sf -u admin:admin123 -X POST -H "Content-Type: application/json" \
                    -d "{\"dashboard\": $(cat "$f"), \"overwrite\": true}" \
                    http://localhost:3000/api/dashboards/db > /dev/null 2>&1 || true
            fi
        done
        echo "   ✅ Dashboards carregados"
        echo ""
        echo "Ambiente Docker pronto para testes! 🎉"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo ""
echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs: docker compose logs transaction-api"
exit 1