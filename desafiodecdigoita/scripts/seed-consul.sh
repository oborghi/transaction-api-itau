#!/bin/bash
set -e

echo "🗄️ Populando Consul com configurações..."
echo ""

export CONSUL_HTTP_ADDR='http://localhost:8500'

# Verifica se Consul está rodando
if ! curl -sf http://localhost:8500/v1/status/leader > /dev/null 2>&1; then
    echo "❌ Consul não está rodando. Execute: docker compose up -d consul"
    exit 1
fi

# Configurações da aplicação
curl -sf -X PUT -d '"mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin"' http://localhost:8500/v1/kv/transaction-api/config/mongodb-uri
curl -sf -X PUT -d '"MyDefaultSecretKeyForDevelopmentOnly2024!"' http://localhost:8500/v1/kv/transaction-api/config/jwt-secret
curl -sf -X PUT -d '"86400"' http://localhost:8500/v1/kv/transaction-api/config/jwt-expiration
curl -sf -X PUT -d '"http://localstack:4566"' http://localhost:8500/v1/kv/transaction-api/config/sqs-endpoint
curl -sf -X PUT -d '"conta-bancaria-criada"' http://localhost:8500/v1/kv/transaction-api/config/sqs-queue
curl -sf -X PUT -d '"conta-bancaria-criada-dlq"' http://localhost:8500/v1/kv/transaction-api/config/dlq-queue
curl -sf -X PUT -d '"50"' http://localhost:8500/v1/kv/transaction-api/config/circuit-breaker-threshold
curl -sf -X PUT -d '"PT5M"' http://localhost:8500/v1/kv/transaction-api/config/dlq-reprocessor-interval
curl -sf -X PUT -d '"true"' http://localhost:8500/v1/kv/transaction-api/config/prometheus-enabled
curl -sf -X PUT -d '"true"' http://localhost:8500/v1/kv/transaction-api/config/otel-enabled

echo ""
echo "✅ Configurações do Consul populadas!"
echo "   Consul UI: http://localhost:8500"