#!/bin/bash

# ==========================================
# Transaction API - Stop All Services
# ==========================================
# Para todos os serviços do projeto:
#   - Aplicação Java (Transaction API via local profile)
#   - Containers Docker (localstack, etc.)
#
# Uso: ./scripts/stop-all.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "🛑 Parando todos os serviços..."

# 1. Matar processos Java da aplicação
JAVA_PIDS=$(pgrep -f "com.itau.transaction.api.TransactionApplicationKt\|spring.profiles.active=local" 2>/dev/null || true)
if [ -n "$JAVA_PIDS" ]; then
    echo "   Parando aplicação Java (PIDs: $JAVA_PIDS)..."
    kill $JAVA_PIDS 2>/dev/null || true
    sleep 2
    # Forçar se ainda estiver rodando
    JAVA_PIDS=$(pgrep -f "com.itau.transaction.api.TransactionApplicationKt\|spring.profiles.active=local" 2>/dev/null || true)
    if [ -n "$JAVA_PIDS" ]; then
        kill -9 $JAVA_PIDS 2>/dev/null || true
    fi
    echo "   ✅ Aplicação Java parada"
else
    echo "   Nenhuma aplicação Java rodando"
fi

# 2. Parar containers Docker
echo "   Parando containers Docker..."
docker compose down 2>/dev/null || true
echo "   ✅ Containers parados"

echo ""
echo "✅ Todos os serviços foram parados."