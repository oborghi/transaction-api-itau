#!/bin/sh
set -e

echo "🚀 Transaction API Docker Entrypoint"
echo "   Profile: ${SPRING_PROFILES_ACTIVE:-default}"
echo ""

# ==========================================
# Vault Secrets Seeding (if Vault enabled)
# ==========================================
if [ "${SPRING_PROFILES_ACTIVE}" = "docker" ]; then
    VAULT_ADDR="http://${VAULT_HOST:-vault}:${VAULT_PORT:-8200}"
    VAULT_TOKEN="${VAULT_TOKEN:-root-token}"
    
    echo "🔐 Waiting for Vault to be ready..."
    RETRIES=0
    MAX_RETRIES=30
    while [ $RETRIES -lt $MAX_RETRIES ]; do
        if curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
            echo "   ✅ Vault is ready"
            break
        fi
        RETRIES=$((RETRIES + 1))
        echo "   ⏳ Waiting for Vault... ($RETRIES/$MAX_RETRIES)"
        sleep 2
    done
    
    if [ $RETRIES -eq $MAX_RETRIES ]; then
        echo "   ⚠️  Vault not available after ${MAX_RETRIES} retries. Continuing with defaults."
    else
        echo "🔐 Seeding Vault secrets..."
        
        # Enable KV v2 secrets engine
        curl -sf -X POST \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d '{"type":"kv-v2"}' \
            "${VAULT_ADDR}/v1/sys/mounts/secret" > /dev/null 2>&1 || true
        
        # MongoDB secret
        curl -sf -X POST \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d '{
                "data": {
                    "uri": "mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin",
                    "username": "admin",
                    "password": "admin123"
                }
            }' \
            "${VAULT_ADDR}/v1/secret/data/transaction-api/mongodb" > /dev/null 2>&1 && \
            echo "   ✅ MongoDB secret" || echo "   ⚠️  MongoDB secret already exists or failed"
        
        # JWT secret
        curl -sf -X POST \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d '{
                "data": {
                    "secret": "MyDefaultSecretKeyForDevelopmentOnly2024!",
                    "issuer": "transaction-api"
                }
            }' \
            "${VAULT_ADDR}/v1/secret/data/transaction-api/jwt" > /dev/null 2>&1 && \
            echo "   ✅ JWT secret" || echo "   ⚠️  JWT secret already exists or failed"
        
        # SQS secret
        curl -sf -X POST \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d '{
                "data": {
                    "endpoint": "http://localstack:4566",
                    "region": "sa-east-1",
                    "access_key": "test",
                    "secret_key": "test"
                }
            }' \
            "${VAULT_ADDR}/v1/secret/data/transaction-api/sqs" > /dev/null 2>&1 && \
            echo "   ✅ SQS secret" || echo "   ⚠️  SQS secret already exists or failed"
        
        # API Credentials secret
        curl -sf -X POST \
            -H "X-Vault-Token: ${VAULT_TOKEN}" \
            -d '{
                "data": {
                    "client_id": "transaction-api-client",
                    "client_secret": "super-secret-key-123"
                }
            }' \
            "${VAULT_ADDR}/v1/secret/data/transaction-api/credentials" > /dev/null 2>&1 && \
            echo "   ✅ Credentials secret" || echo "   ⚠️  Credentials secret already exists or failed"
        
        echo "   🔐 Vault seeding complete"
    fi
fi

echo ""
echo "🚀 Starting Transaction API..."
echo "   Profile: ${SPRING_PROFILES_ACTIVE:-default}"
echo ""

# Start the application with the external classpath approach
exec java -cp "app.jar:libs/*" com.itau.transaction.api.TransactionApplicationKt "$@"