#!/bin/bash
set -e

echo "🗄️ Populando Consul com configs da aplicação..."
echo ""

CONSUL_ADDR="${CONSUL_HTTP_ADDR:-http://localhost:8500}"

# Verifica se Consul está rodando
if ! curl -sf "$CONSUL_ADDR/v1/status/leader" > /dev/null 2>&1; then
    echo "❌ Consul não está rodando. Execute: docker compose up -d consul"
    exit 1
fi

echo "📋 Configurações da aplicação no Consul (KV):"

# Configurações da aplicação (prefixo: transaction-api/config/)
curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/jwt-secret" -d "MyDefaultSecretKeyForDevelopmentOnly2024!"
echo "   ✅ jwt-secret"

curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/jwt-expiration" -d "86400"
echo "   ✅ jwt-expiration"

curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/sqs-queue-url" -d "http://localstack:4566/000000000000/conta-bancaria-criada"
echo "   ✅ sqs-queue-url"

curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/circuit-breaker-threshold" -d "50"
echo "   ✅ circuit-breaker-threshold"

curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/prometheus-enabled" -d "true"
echo "   ✅ prometheus-enabled"

curl -sf -X PUT "$CONSUL_ADDR/v1/kv/transaction-api/config/dlq-reprocessor-interval" -d "PT5M"
echo "   ✅ dlq-reprocessor-interval"

echo ""
echo "📋 Verificando configurações gravadas:"
for key in jwt-secret jwt-expiration sqs-queue-url circuit-breaker-threshold prometheus-enabled dlq-reprocessor-interval; do
    VALUE=$(curl -sf "$CONSUL_ADDR/v1/kv/transaction-api/config/$key?raw" 2>/dev/null || echo "N/A")
    echo "   $key = $VALUE"
done

echo ""
echo "✅ Configurações do Consul populadas!"
echo "   UI: $CONSUL_ADDR"
echo "   Hotswap: Alterações via PUT são refletidas automaticamente (watch delay=1s)"