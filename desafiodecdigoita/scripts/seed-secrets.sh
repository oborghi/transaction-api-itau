#!/bin/bash
set -e

echo "🔐 Populando Vault com secrets..."
echo ""

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root-token'

# Verifica se Vault está rodando
if ! curl -sf http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
    echo "❌ Vault não está rodando. Execute: docker compose up -d vault"
    exit 1
fi

# Enable KV secrets engine
vault secrets enable -path=secret kv-v2 2>/dev/null || true

# MongoDB secret
vault kv put secret/transaction-api/mongodb \
  uri="mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin" \
  username="admin" \
  password="admin123"

echo "   ✅ MongoDB secret"

# JWT secret
vault kv put secret/transaction-api/jwt \
  secret="MyDefaultSecretKeyForDevelopmentOnly2024!" \
  issuer="transaction-api"

echo "   ✅ JWT secret"

# SQS secret
vault kv put secret/transaction-api/sqs \
  access_key="test" \
  secret_key="test" \
  region="sa-east-1" \
  endpoint="http://localstack:4566"

echo "   ✅ SQS secret"

# API credentials
vault kv put secret/transaction-api/credentials \
  client_id="transaction-api-client" \
  client_secret="super-secret-key-123"

echo "   ✅ Credentials secret"

echo ""
echo "✅ Todos os secrets populados no Vault!"
echo "   Vault UI: http://localhost:8200 (token: root-token)"