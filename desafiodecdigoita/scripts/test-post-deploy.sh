#!/bin/bash
set -euo pipefail

# ==========================================
# Transaction API - Teste Pós-Deploy AWS
# ==========================================
# Este script executa uma bateria de testes
# contra o ambiente AWS recém-deployado.
#
# Uso:
#   source scripts/env-aws.sh
#   ./scripts/test-post-deploy.sh
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==========================================
# Funções auxiliares
# ==========================================
print_header() {
    echo ""
    echo "=========================================="
    echo "🧪 Teste Pós-Deploy - Transaction API"
    echo "=========================================="
    echo ""
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ "$result" = true ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "   ${GREEN}✅${NC} ${test_name}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "   ${RED}❌${NC} ${test_name}"
        echo -e "   ${RED}   → ${details}${NC}"
    fi
}

check_dependency() {
    local cmd="$1"
    local name="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "   ${RED}❌${NC} ${name} não encontrado. Instale: apt install ${cmd}"
        exit 1
    fi
}

get_token() {
    local api_url="$1"
    local client_id="$2"
    local client_secret="$3"
    curl -s -X POST "${api_url}/api/v1/auth/token" \
        -H 'Content-Type: application/json' \
        -d "{\"client_id\":\"${client_id}\",\"client_secret\":\"${client_secret}\"}" | jq -r '.token'
}

# ==========================================
# Verificação inicial
# ==========================================
print_header

# Verificar se env-aws.sh foi sourced
if [ -z "${API_URL:-}" ]; then
    echo -e "${YELLOW}⚠️${NC} Variáveis de ambiente AWS não carregadas."
    echo "   Execute: source scripts/env-aws.sh"
    echo ""
    echo "   Ou forneça manualmente:"
    echo "   export API_URL=http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com"
    echo "   export CLIENT_SECRET=AxIp+2lLcgdYV8oVYrC15w=="
    echo ""

    # Tentar usar defaults
    API_URL="${API_URL:-http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com}"
    CLIENT_ID="${CLIENT_ID:-transaction-api-client}"
    CLIENT_SECRET="${CLIENT_SECRET:-AxIp+2lLcgdYV8oVYrC15w==}"
    SQS_QUEUE_URL="${SQS_QUEUE_URL:-https://sqs.sa-east-1.amazonaws.com/219173034456/transaction-api_conta-bancaria-criada}"
    AWS_REGION="${AWS_DEFAULT_REGION:-sa-east-1}"
fi

# Verificar dependências
check_dependency "curl" "curl"
check_dependency "jq"   "jq"
check_dependency "aws"  "AWS CLI v2"

echo ""
echo -e "${BLUE}🔗${NC} ALB DNS: ${API_URL}"
echo -e "${BLUE}🔗${NC} Região:  ${AWS_REGION}"
echo ""

# ==========================================
# Teste 1: Health Check
# ==========================================
echo -e "${BLUE}📋${NC} Teste 1: Health Check da API"
echo "   curl -s ${API_URL}/actuator/health"
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/actuator/health" 2>/dev/null || echo "000")
HEALTH_BODY=$(curl -s "${API_URL}/actuator/health" 2>/dev/null || echo "{}")
MONGO_STATUS=$(echo "$HEALTH_BODY" | jq -r '.components.mongo.status // "UNKNOWN"')

if [ "$HEALTH_RESPONSE" = "200" ]; then
    print_test_result "Health Check (HTTP ${HEALTH_RESPONSE})" true ""
else
    print_test_result "Health Check (HTTP ${HEALTH_RESPONSE})" false "Esperado 200, recebido ${HEALTH_RESPONSE}"
fi

if [ "$MONGO_STATUS" = "UP" ]; then
    print_test_result "MongoDB Status (${MONGO_STATUS})" true ""
else
    print_test_result "MongoDB Status (${MONGO_STATUS})" false "MongoDB não está UP"
fi

echo ""

# ==========================================
# Teste 2: Geração de Token JWT
# ==========================================
echo -e "${BLUE}📋${NC} Teste 2: Geração de Token JWT"
echo "   curl -s -X POST ${API_URL}/api/v1/auth/token"

TOKEN=$(get_token "$API_URL" "$CLIENT_ID" "$CLIENT_SECRET" 2>/dev/null || echo "")

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    print_test_result "Token JWT gerado com sucesso" true ""
    # Verificar se o token tem 3 partes (JWT válido)
    JWT_PARTS=$(echo "$TOKEN" | awk -F'.' '{print NF}')
    if [ "$JWT_PARTS" -eq 3 ]; then
        print_test_result "Token JWT possui 3 partes (válido)" true ""
    else
        print_test_result "Token JWT possui ${JWT_PARTS} partes" false "JWT deve ter 3 partes (header.payload.signature)"
    fi
else
    print_test_result "Token JWT gerado com sucesso" false "Token vazio ou nulo"
fi

echo ""

# ==========================================
# Teste 3: Seed de Contas via SQS
# ==========================================
echo -e "${BLUE}📋${NC} Teste 3: Seed de Contas via SQS"
echo "   Enviando 3 contas de teste para SQS..."

SEED_SUCCESS=true
for i in 1 2 3; do
    ACCOUNT_ID=$(uuidgen 2>/dev/null || echo "acc-$(date +%s)-${i}")
    OWNER_ID=$(uuidgen 2>/dev/null || echo "owner-$(date +%s)-${i}")
    CREATED_AT=$(date +%s)

    if aws sqs send-message \
        --queue-url "$SQS_QUEUE_URL" \
        --region "$AWS_REGION" \
        --message-body "{\"account\":{\"id\":\"${ACCOUNT_ID}\",\"owner\":\"${OWNER_ID}\",\"created_at\":${CREATED_AT},\"status\":\"ENABLED\"}}" \
        > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅${NC} Conta ${i} enviada: ${ACCOUNT_ID}"
    else
        echo -e "   ${RED}❌${NC} Falha ao enviar conta ${i}"
        SEED_SUCCESS=false
    fi
done

if [ "$SEED_SUCCESS" = true ]; then
    print_test_result "Seed de contas via SQS" true ""
else
    print_test_result "Seed de contas via SQS" false "Falha ao enviar mensagens SQS"
fi

echo ""

# ==========================================
# Teste 4: Transação CREDIT
# ==========================================
echo -e "${BLUE}📋${NC} Teste 4: Transação CREDIT (R\$ 100,00)"
echo "   Aguardando 15s para processamento das contas..."
sleep 15

# Buscar account_id do MongoDB (usar um dos que foram seedados)
# Como não temos endpoint de listagem, usamos um ID fixo do seed anterior
ACCOUNT_ID="06355ccf-ddb7-42a1-93c7-6dd128dba80b"
TX_ID="tx-$(date +%s)"

CREDIT_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/transactions/${TX_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"account_id\":\"${ACCOUNT_ID}\",\"type\":\"CREDIT\",\"amount\":{\"value\":100.00,\"currency\":\"BRL\"}}" 2>/dev/null || echo "{}")

TX_STATUS=$(echo "$CREDIT_RESPONSE" | jq -r '.transaction.status // "ERROR"')
BALANCE=$(echo "$CREDIT_RESPONSE" | jq -r '.account.balance.value // "0"')

if [ "$TX_STATUS" = "SUCCEEDED" ] || [ "$TX_STATUS" = "APPROVED" ]; then
    print_test_result "CREDIT R\$ 100,00 (status=${TX_STATUS}, saldo=${BALANCE})" true ""
else
    ERROR_MSG=$(echo "$CREDIT_RESPONSE" | jq -r '.error // .message // "unknown"')
    print_test_result "CREDIT R\$ 100,00 (status=${TX_STATUS})" false "Erro: ${ERROR_MSG}"
fi

echo ""

# ==========================================
# Teste 5: Transação DEBIT (saldo suficiente)
# ==========================================
echo -e "${BLUE}📋${NC} Teste 5: Transação DEBIT (R\$ 30,00)"
TX_ID="tx-$(date +%s)"

DEBIT_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/transactions/${TX_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"account_id\":\"${ACCOUNT_ID}\",\"type\":\"DEBIT\",\"amount\":{\"value\":30.00,\"currency\":\"BRL\"}}" 2>/dev/null || echo "{}")

TX_STATUS=$(echo "$DEBIT_RESPONSE" | jq -r '.transaction.status // "ERROR"')
BALANCE=$(echo "$DEBIT_RESPONSE" | jq -r '.account.balance.value // "0"')

if [ "$TX_STATUS" = "SUCCEEDED" ] || [ "$TX_STATUS" = "APPROVED" ]; then
    print_test_result "DEBIT R\$ 30,00 (status=${TX_STATUS}, saldo=${BALANCE})" true ""
else
    ERROR_MSG=$(echo "$DEBIT_RESPONSE" | jq -r '.error // .message // "unknown"')
    print_test_result "DEBIT R\$ 30,00 (status=${TX_STATUS})" false "Erro: ${ERROR_MSG}"
fi

echo ""

# ==========================================
# Teste 6: Transação DEBIT (saldo insuficiente)
# ==========================================
echo -e "${BLUE}📋${NC} Teste 6: Transação DEBIT (R\$ 999.999,00 - saldo insuficiente)"
TX_ID="tx-$(date +%s)"

INSUFFICIENT_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/transactions/${TX_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "{\"account_id\":\"${ACCOUNT_ID}\",\"type\":\"DEBIT\",\"amount\":{\"value\":999999.00,\"currency\":\"BRL\"}}" 2>/dev/null || echo "{}")

ERROR_TYPE=$(echo "$INSUFFICIENT_RESPONSE" | jq -r '.error // "UNKNOWN"')

if [ "$ERROR_TYPE" = "INSUFFICIENT_BALANCE" ]; then
    print_test_result "DEBIT saldo insuficiente (error=${ERROR_TYPE})" true ""
else
    print_test_result "DEBIT saldo insuficiente (error=${ERROR_TYPE})" false "Esperado INSUFFICIENT_BALANCE"
fi

echo ""

# ==========================================
# Teste 7: Swagger UI
# ==========================================
echo -e "${BLUE}📋${NC} Teste 7: Swagger UI"
SWAGGER_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/swagger-ui.html" 2>/dev/null || echo "000")

if [ "$SWAGGER_CODE" = "200" ] || [ "$SWAGGER_CODE" = "302" ]; then
    print_test_result "Swagger UI (HTTP ${SWAGGER_CODE})" true ""
else
    print_test_result "Swagger UI (HTTP ${SWAGGER_CODE})" false "Esperado 200 ou 302"
fi

echo ""

# ==========================================
# Teste 8: Actuator Metrics
# ==========================================
echo -e "${BLUE}📋${NC} Teste 8: Actuator Metrics"
METRICS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/actuator/metrics" 2>/dev/null || echo "000")

if [ "$METRICS_CODE" = "200" ]; then
    print_test_result "Actuator Metrics (HTTP ${METRICS_CODE})" true ""
else
    print_test_result "Actuator Metrics (HTTP ${METRICS_CODE})" false "Esperado 200"
fi

echo ""

# ==========================================
# Resumo Final
# ==========================================
echo "=========================================="
echo -e " ${GREEN}📊${NC} Resumo dos Testes"
echo "=========================================="
echo ""
echo -e "   ${GREEN}✅${NC} Passados: ${TESTS_PASSED}/${TESTS_TOTAL}"
echo -e "   ${RED}❌${NC} Falhos:   ${TESTS_FAILED}/${TESTS_TOTAL}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e " ${GREEN}🎉${NC} TODOS OS TESTES PASSARAM!"
    echo ""
    echo "   A API está operacional na AWS com:"
    echo "   - Health Check:    ${API_URL}/actuator/health"
    echo "   - Swagger UI:      ${API_URL}/swagger-ui.html"
    echo "   - Auth:            ${API_URL}/api/v1/auth/token"
    echo "   - Transactions:    ${API_URL}/api/v1/transactions/{id}"
    echo ""
    echo "   Credenciais:"
    echo "   - client_id:       ${CLIENT_ID}"
    echo "   - client_secret:   ${CLIENT_SECRET}"
    echo ""
    echo "   Para usar:"
    echo "   source scripts/env-aws.sh"
    exit 0
else
    echo -e " ${RED}⚠️${NC}  ${TESTS_FAILED} teste(s) falharam. Verifique os logs acima."
    echo ""
    echo "   Logs da aplicação:"
    echo "   aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs/transaction-api-app --region ${AWS_REGION}"
    exit 1
fi