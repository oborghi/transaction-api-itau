#!/bin/bash
set -e

# ==========================================
# Transaction API - Docker Profile (LocalStack)
# ==========================================
# Roda toda a aplicação em containers Docker:
#   - LocalStack (SQS, Secrets Manager, SSM, DocumentDB, CloudWatch)
#   - Transaction API (Spring Boot)
#
# Uso: ./scripts/run-docker.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

cleanup() {
    echo ""
    echo "🧹 Limpando recursos..."
    docker compose down 2>/dev/null || true
    echo "✅ Limpeza concluída."
}
trap cleanup ERR

echo "🐳 Iniciando ambiente Docker..."
echo "   - LocalStack (SQS, Secrets Manager, SSM, DocumentDB, CloudWatch)"
echo "   - Transaction API"
echo ""

# ==========================================
# 1. Verificar pré-requisitos
# ==========================================
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está acessível."
    if [ -S /var/run/docker.sock ]; then
        echo "   - O socket /var/run/docker.sock existe, mas o daemon não responde ou você não tem permissão."
    else
        echo "   - O socket /var/run/docker.sock não existe."
    fi
    echo "   - Inicie o Docker daemon ou habilite Docker Rootless antes de executar este script."

    if ! command -v dockerd >/dev/null 2>&1; then
        echo "   - O binário dockerd não está disponível. Instale o Docker Engine."
    fi
    if ! command -v docker-rootless.sh >/dev/null 2>&1 && ! command -v dockerd-rootless.sh >/dev/null 2>&1; then
        echo "   - O Docker Rootless não está instalado."
    else
        if ! command -v newuidmap >/dev/null 2>&1 || ! command -v newgidmap >/dev/null 2>&1; then
            echo "   - Docker Rootless requer newuidmap e newgidmap. Instale-os para usar rootless."
        fi
        if [ ! -f /etc/subuid ] || [ ! -f /etc/subgid ]; then
            echo "   - Configure /etc/subuid e /etc/subgid para o usuário atual."
        fi
    fi
    exit 1
fi

# ==========================================
# 2. Parar serviços anteriores
# ==========================================
echo "🛑 Parando serviços anteriores..."

# Mata LocalStack local (CLI) se estiver rodando para evitar conflito de porta
if command -v localstack &> /dev/null; then
    echo "   Parando LocalStack CLI (se estiver rodando)..."
    localstack stop 2>/dev/null || true
fi

# Para containers Docker anteriores
bash "$SCRIPT_DIR/stop-all.sh"

# ==========================================
# 3. Subir infraestrutura (LocalStack)
# ==========================================
echo "📦 Subindo infraestrutura..."
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
# 5. Recursos do LocalStack (SQS, S3, Secrets)
# ==========================================
# SQS queues, S3 bucket e Secrets são criados automaticamente
# pelo script init-localstack.sh montado em /etc/localstack/init/ready.d/
# que o LocalStack executa ao atingir o estado "ready".

# ==========================================
# 6. Subir aplicação
# ==========================================
echo ""
echo "🚀 Subindo Transaction API..."
docker compose up -d --build transaction-api

# ==========================================
# 8. Aguardar API ficar saudável
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
        echo ""
        echo "🌱 Populando contas de teste..."
        bash "$SCRIPT_DIR/seed-accounts.sh"
        echo ""
        echo "📋 AWS Services (via LocalStack): http://localhost:4566"
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