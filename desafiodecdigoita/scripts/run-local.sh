#!/bin/bash
set -e

# ==========================================
# Transaction API - Local Profile
# ==========================================
# Infraestrutura roda em Docker, aplicação roda via Java local:
#   - LocalStack (SQS) via Docker
#   - MongoDB via Docker
#   - Vault (Secrets) via Docker
#   - Consul (Config) via Docker
#   - Prometheus, Grafana, Jaeger, Loki via Docker
#   - Transaction API via Java (local com Spring profile=local)
#
# Pré-requisitos: Java 21+, Maven 3.9+, Docker
# Uso: ./scripts/run-local.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

APP_PID=""

# Cleanup: kill Java process e para containers ao sair
cleanup() {
    echo ""
    echo "🧹 Limpando recursos..."
    if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
        echo "   Parando aplicação Java (PID: $APP_PID)..."
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
    echo "   Parando containers Docker..."
    docker compose down 2>/dev/null || true
    echo "✅ Limpeza concluída."
}
trap cleanup EXIT INT TERM

echo "🚀 Iniciando ambiente local..."
echo "   - LocalStack (SQS) via Docker"
echo "   - MongoDB via Docker"
echo "   - Vault (Secrets) via Docker"
echo "   - Consul (Config) via Docker"
echo "   - Transaction API via Java (local)"
echo "   - Prometheus / Grafana / Jaeger / Loki via Docker"
echo ""

# ==========================================
# 1. Verificar pré-requisitos
# ==========================================
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo "❌ Java não encontrado. Instale o JDK 21."
    exit 1
fi

if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado. Instale o Maven."
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
# 3. Subir infraestrutura + observabilidade via Docker
# ==========================================
echo "📦 Subindo infraestrutura + observabilidade via Docker..."
docker compose up -d localstack mongodb vault consul prometheus jaeger loki grafana

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

export AWS_DEFAULT_REGION=sa-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# Aguarda LocalStack estar pronto
sleep 3

aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada 2>/dev/null || true
aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada-dlq 2>/dev/null || true
echo "   ✅ Filas SQS criadas"

# ==========================================
# 6. Popula Vault com secrets
# ==========================================
echo ""
echo "🔐 Populando Vault com secrets..."

sleep 2

VAULT_ENV="-e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root-token"

docker exec $VAULT_ENV vault vault secrets enable -path=secret kv-v2 2>/dev/null || true

docker exec $VAULT_ENV vault vault kv put secret/transaction-api/mongodb \
  uri="mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin" \
  username="admin" \
  password="admin123"
echo "   ✅ MongoDB secret"

docker exec $VAULT_ENV vault vault kv put secret/transaction-api/jwt \
  secret="MyDefaultSecretKeyForDevelopmentOnly2024!" \
  issuer="transaction-api"
echo "   ✅ JWT secret"

docker exec $VAULT_ENV vault vault kv put secret/transaction-api/sqs \
  access_key="test" \
  secret_key="test" \
  region="sa-east-1" \
  endpoint="http://localstack:4566"
echo "   ✅ AWS/SQS secret"

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
# 8. Build e iniciar aplicação via Java
# ==========================================
echo ""
echo "🚀 Subindo Transaction API via Java (local)..."
echo "   Profile: local"
echo "   Porta: 8080"
echo ""

echo "📦 Construindo a aplicação..."
mvn clean package -DskipTests -B -q

JAR_FILE="transaction-api/target/transaction-api-1.0.0-SNAPSHOT.jar"
LIBS_DIR="transaction-api/target/libs"

if [ ! -f "$JAR_FILE" ]; then
    echo "❌ JAR não encontrado: $JAR_FILE"
    exit 1
fi

if [ ! -d "$LIBS_DIR" ]; then
    echo "❌ Diretório libs não encontrado: $LIBS_DIR"
    exit 1
fi

echo "🚀 Iniciando aplicação com java -cp..."
java -cp "$JAR_FILE:$LIBS_DIR/*" \
    -Dspring.profiles.active=local \
    -Dserver.port=8080 \
    com.itau.transaction.api.TransactionApplicationKt &
APP_PID=$!

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
        echo "� Observability:"
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
        echo "Ambiente local pronto para testes! 🎉"
        echo ""
        echo "   Pressione Ctrl+C para parar todos os serviços."
        echo ""

        # Mantém o script rodando para que o trap funcione
        wait "$APP_PID" 2>/dev/null
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo ""
echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs."
exit 1