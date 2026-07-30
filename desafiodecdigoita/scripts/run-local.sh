#!/bin/bash
set -e

# ==========================================
# Transaction API - Local Profile
# ==========================================
# LocalStack via Docker, Transaction API via Java (local)
# Ideal para desenvolvimento: rapidamente iterar no código sem rebuildar container
#
# Pré-requisitos: Java 21+, Maven 3.9+, Docker
# Uso: ./scripts/run-local.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$RUN_LOCAL_INVOKED" ] && [ -n "$SHELL" ] && [ -x "$SHELL" ]; then
    echo "🔄 Reexecutando script em shell de login ($SHELL) para herdar PATH/SDKMAN..."
    export RUN_LOCAL_INVOKED=1
    exec "$SHELL" -lc "cd '$PROJECT_DIR' && RUN_LOCAL_INVOKED=1 bash '$SCRIPT_DIR/run-local.sh'"
fi

cd "$PROJECT_DIR"

echo "🚀 Iniciando ambiente local..."
echo "   - LocalStack via Docker (SQS, Secrets Manager, DocumentDB, CloudWatch, X-Ray)"
echo "   - Transaction API via Java (local)"
echo ""

# ==========================================
# 1. Verificar pré-requisitos
# ==========================================
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está acessível."
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo "❌ Java não encontrado. Instale o JDK 21."
    exit 1
fi

if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado."
    exit 1
fi

# ==========================================
# 2. Parar serviços anteriores
# ==========================================
echo "🛑 Parando serviços anteriores..."
bash "$SCRIPT_DIR/stop-all.sh"

# ==========================================
# 3. Subir LocalStack via Docker
# ==========================================
echo "📦 Subindo LocalStack via Docker..."
docker compose up -d localstack

wait_for_service() {
    local url="$1"
    local attempts=0
    local max=20
    while [ $attempts -lt $max ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi
        attempts=$((attempts + 1))
        echo "   Aguardando serviço em $url... tentativa $attempts/$max"
        sleep 3
    done
    return 1
}

# ==========================================
# 4. Aguardar LocalStack ficar saudável
# ==========================================
echo ""
echo "⏳ Aguardando LocalStack ficar saudável..."
if wait_for_service "http://127.0.0.1:4566/_localstack/health"; then
    echo "✅ LocalStack está rodando em http://127.0.0.1:4566"
else
    echo "❌ LocalStack não ficou saudável após várias tentativas."
    exit 1
fi

# ==========================================
# 5. Criar recursos via init-localstack.sh
# ==========================================
echo ""
echo "📦 Executando init-localstack.sh via docker exec..."
docker compose exec -T localstack bash /etc/localstack/init/ready.d/init-localstack.sh
echo ""

# ==========================================
# 6. Build e iniciar aplicação via Java
# ==========================================
echo "🚀 Construindo a aplicação..."
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

mkdir -p logs

# Carrega as variáveis de ambiente para local
source "$SCRIPT_DIR/env-local.sh"

echo "🚀 Iniciando aplicação com java -cp..."
nohup java -cp "$JAR_FILE:$LIBS_DIR/*" \
    -Dserver.port=${SERVER_PORT:-8080} \
    com.itau.transaction.api.TransactionApplicationKt \
    > logs/transaction-api-local.out 2>&1 &
APP_PID=$!

echo "   Java iniciado em segundo plano (PID: $APP_PID)"
echo "   Saída: logs/transaction-api-local.out"
echo ""

# ==========================================
# 7. Aguardar API ficar saudável
# ==========================================
echo "⏳ Aguardando API ficar saudável..."

MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://127.0.0.1:8080/actuator/health > /dev/null 2>&1; then
        echo ""
        echo "✅ API está rodando em http://127.0.0.1:8080"
        echo "   - Swagger UI: http://127.0.0.1:8080/swagger-ui.html"
        echo "   - Health: http://127.0.0.1:8080/actuator/health"
        echo "   - AWS: http://localhost:4566"
        echo ""
        echo "📋 Token:"
        echo '   curl -X POST http://127.0.0.1:8080/api/v1/auth/token \'
        echo '     -H "Content-Type: application/json" \'
        echo '     -d '"'"'{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'"'"''
        echo ""
        echo ""
        echo "🌱 Populando contas de teste..."
        bash "$SCRIPT_DIR/seed-accounts.sh"
        echo ""
        echo "📌 Logs: logs/transaction-api-local.out"
        echo "📌 Parar: ./scripts/stop-all.sh"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo ""
echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs: logs/transaction-api-local.out"
exit 1