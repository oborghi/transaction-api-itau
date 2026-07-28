#!/bin/bash
set -e

echo "🚀 Iniciando ambiente local..."
echo "   - LocalStack (SQS) via Docker"
echo "   - MongoDB via Docker"
echo "   - Vault (Secrets) via Docker"
echo "   - Consul (Config) via Docker"
echo "   - Transaction API via Java (local)"
echo ""

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# Verifica se Java está instalado
if ! command -v java &> /dev/null; then
    echo "❌ Java não encontrado. Instale o JDK 21."
    exit 1
fi

# Verifica se Maven está instalado
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado. Instale o Maven."
    exit 1
fi

# Criar pastas de dados (volumes do host)
mkdir -p data/{mongodb,prometheus,loki,grafana,vault,consul}

# Limpar dados anteriores
echo "🧹 Limpando dados anteriores..."
rm -rf data/consul/* data/mongodb/* data/prometheus/* data/loki/* data/grafana/* data/vault/* 2>/dev/null || true

# Para containers anteriores e limpa volumes
echo "🛑 Parando containers anteriores e limpando volumes..."
docker compose down -v 2>/dev/null || true

# Sobe apenas infraestrutura (Vault, MongoDB, LocalStack, Consul)
echo "📦 Subindo infraestrutura via Docker..."
docker compose up -d localstack mongodb vault consul

echo ""
echo "⏳ Aguardando Vault ficar saudável..."

# Aguarda Vault ficar pronto
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

# Inicializa filas SQS no LocalStack
echo ""
echo "📨 Inicializando filas SQS no LocalStack..."

export AWS_DEFAULT_REGION=sa-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# Aguarda LocalStack estar pronto
sleep 3

# Cria filas SQS
aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada 2>/dev/null || true
aws --endpoint-url=http://localhost:4566 --region sa-east-1 sqs create-queue --queue-name conta-bancaria-criada-dlq 2>/dev/null || true
echo "   ✅ Filas SQS criadas"

# Popula Vault com secrets usando docker exec
echo ""
echo "🔐 Populando Vault com secrets..."

# Aguarda Vault estar pronto para writes
sleep 2

# Variáveis para comandos vault via docker exec
VAULT_ENV="-e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root-token"

# Enable KV secrets engine
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

# Popula Consul com configs usando docker exec
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

# Sobe a aplicação via Java (mesmo método do Docker)
echo ""
echo "🚀 Subindo Transaction API..."
echo "   Profile: local"
echo "   Porta: 8080"
echo ""

# Descobre o diretório raiz do projeto (pai do diretório scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Primeiro, constrói a aplicação
echo "📦 Construindo a aplicação..."
mvn clean package -DskipTests -B -q

# Verifica se os arquivos necessários existem
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

# Executa a aplicação com o classpath correto (mesmo método do Docker)
echo "🚀 Iniciando aplicação com java -cp..."
java -cp "$JAR_FILE:$LIBS_DIR/*" \
    -Dspring.profiles.active=local \
    -Dserver.port=8080 \
    com.itau.transaction.api.TransactionApplicationKt &
APP_PID=$!

echo ""
echo "⏳ Aguardando API ficar saudável..."

# Aguarda healthcheck da API
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
        echo "📋 Para parar a aplicação:"
        echo "   kill $APP_PID"
        echo "   docker compose down -v"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs."
kill $APP_PID 2>/dev/null || true
exit 1