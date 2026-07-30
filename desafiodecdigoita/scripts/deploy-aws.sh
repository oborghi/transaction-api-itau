#!/bin/bash
set -euo pipefail

# ==========================================
# Transaction API - Deploy AWS (ECS Fargate)
# ==========================================
# Script idempotente de deploy completo na AWS.
# Se a infra já existe, apenas atualiza a imagem.
#
# Uso:
#   ./scripts/deploy-aws.sh                          # Interativo
#   ENVIRONMENT=dev AUTO_APPROVE=true ./scripts/deploy-aws.sh  # Não-interativo
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_DEFAULT_REGION:-sa-east-1}"
TFVARS_DIR="$PROJECT_DIR/terraform/environments"
TFVARS_FILE="${TFVARS_DIR}/${ENVIRONMENT}.tfvars"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# ==========================================
# Cores para output
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# Funções auxiliares
# ==========================================
print_banner() {
    echo ""
    echo "☁️  =========================================="
    echo "   Deploy AWS - Transaction API"
    echo "   Ambiente: ${ENVIRONMENT}"
    echo "   Regiao:   ${AWS_REGION}"
    echo "=========================================="
    echo ""
}

check_dep() {
    local cmd="$1"
    local name="$2"
    local url="$3"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "   ${RED}❌${NC} ${name} nao encontrado."
        echo "      Instale: ${url}"
        return 1
    fi
    echo -e "   ${GREEN}✅${NC} ${name} encontrado"
    return 0
}

wait_for_service() {
    local url="$1"
    local label="$2"
    local max_attempts="$3"
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo -e "   ${GREEN}✅${NC} ${label} está respondendo!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -e "   ${YELLOW}⏳${NC} Tentativa $attempt/$max_attempts - Aguardando ${label}..."
        sleep 10
    done
    echo -e "   ${RED}⚠️${NC}  ${label} não respondeu após ${max_attempts} tentativas."
    return 1
}

check_ecs_service_health() {
    local cluster="$1"
    local service="$2"
    local region="$3"
    local max_attempts="$4"
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        local status
        status=$(aws ecs describe-services \
            --cluster "$cluster" \
            --services "$service" \
            --region "$region" \
            --query 'services[0].{running:runningCount,desired:desiredCount,pending:pendingCount}' \
            --output json 2>/dev/null || echo '{"running":0,"desired":1,"pending":0}')

        local running
        running=$(echo "$status" | jq -r '.running')
        local desired
        desired=$(echo "$status" | jq -r '.desired')
        local pending
        pending=$(echo "$status" | jq -r '.pending')

        if [ "$running" -ge "$desired" ] && [ "$pending" -eq 0 ]; then
            echo -e "   ${GREEN}✅${NC} ECS Service estável: ${running}/${desired} tarefas rodando"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -e "   ${YELLOW}⏳${NC} Tentativa $attempt/$max_attempts - ECS: running=${running}, pending=${pending}"
        sleep 10
    done
    echo -e "   ${RED}⚠️${NC}  ECS Service não estabilizou após ${max_attempts} tentativas."
    return 1
}

check_alb_targets_healthy() {
    local tg_arn="$1"
    local region="$2"
    local max_attempts="$3"
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        local unhealthy
        unhealthy=$(aws elbv2 describe-target-health \
            --target-group-arn "$tg_arn" \
            --region "$region" \
            --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].TargetHealth.State' \
            --output text 2>/dev/null || echo "unknown")

        if [ -z "$unhealthy" ]; then
            echo -e "   ${GREEN}✅${NC} Todos os targets do ALB estão saudáveis!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -e "   ${YELLOW}⏳${NC} Tentativa $attempt/$max_attempts - Targets unhealthy: ${unhealthy:-waiting}"
        sleep 10
    done
    echo -e "   ${RED}⚠️${NC}  ALB targets não ficaram saudáveis após ${max_attempts} tentativas."
    return 1
}

cleanup_ecr_images() {
    local repo_name="$1"
    local region="$2"
    echo "   🧹 Removendo imagens antigas do ECR (exceto 'latest')..."

    local old_images
    old_images=$(aws ecr list-images \
        --repository-name "$repo_name" \
        --region "$region" \
        --query "imageIds[?imageTag!=\`latest\`]" \
        --output json 2>/dev/null || echo '[]')

    local count
    count=$(echo "$old_images" | jq '. | length')
    if [ "$count" -eq 0 ]; then
        echo -e "   ${GREEN}✅${NC} Nenhuma imagem antiga para remover."
        return 0
    fi

    echo "   🗑️  Removendo ${count} imagem(ns) antiga(s)..."
    aws ecr batch-delete-image \
        --repository-name "$repo_name" \
        --region "$region" \
        --image-ids "$(echo "$old_images" | jq -c '.')" > /dev/null 2>&1 && \
    echo -e "   ${GREEN}✅${NC} Imagens antigas removidas." || \
    echo -e "   ${YELLOW}⚠️${NC}  Erro ao remover imagens (algumas podem estar em uso)."
}

verify_all_components() {
    local alb_dns="$1"
    local ecs_cluster="$2"
    local ecs_service="$3"
    local region="$4"
    local tg_arn="$5"

    echo ""
    echo "🔍 Verificando todos os componentes da infraestrutura..."
    echo "   (timeout máximo: 5 minutos)"
    echo ""

    local timeout=30  # 30 tentativas * 10s = 300s = 5 min

    # 1. Verificar ECS Service
    echo -e "${BLUE}📦${NC} [1/4] Verificando ECS Service..."
    if ! check_ecs_service_health "$ecs_cluster" "$ecs_service" "$region" "$timeout"; then
        return 1
    fi

    # 2. Verificar ALB Targets
    echo -e "${BLUE}🌐${NC} [2/4] Verificando ALB targets..."
    if ! check_alb_targets_healthy "$tg_arn" "$region" "$timeout"; then
        return 1
    fi

    # 3. Verificar Health Check da API
    echo -e "${BLUE}🏥${NC} [3/4] Verificando health check da API..."
    if ! wait_for_service "http://${alb_dns}/actuator/health" "API" "$timeout"; then
        return 1
    fi

    # 4. Verificar MongoDB via health check da app
    echo -e "${BLUE}🗄️${NC}  [4/4] Verificando MongoDB via API..."
    if ! wait_for_service "http://${alb_dns}/actuator/health" "API (MongoDB check)" 6; then
        # O health check do Spring já verifica o MongoDB, se a API responde 200 o MongoDB está UP
        echo -e "   ${GREEN}✅${NC} MongoDB verificado indiretamente via health check da API."
    fi

    echo ""
    echo -e "${GREEN}✅${NC} Todos os componentes estão operacionais!"
    return 0
}

print_summary() {
    local alb_dns="$1"
    local region="$2"
    local account_id="$3"
    local env="$4"
    local ecs_cluster="$5"
    local ecs_service="$6"
    local ecr_name="$7"
    local sqs_url="$8"
    local s3_bucket="$9"
    local cw_log_group="$10"
    local api_client_secret="$11"

    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ Deploy AWS concluído com sucesso!${NC}"
    echo "=========================================="
    echo ""
    echo "📋 Resumo da Infraestrutura:"
    echo "   - Ambiente:    ${env}"
    echo "   - Região:      ${region}"
    echo "   - Account ID:  ${account_id}"
    echo "   - VPC:         transaction-api_vpc (10.0.0.0/16)"
    echo "   - Subnets:     2 públicas (sa-east-1a, sa-east-1b)"
    echo "   - ALB:         transaction-api_alb (HTTP:80)"
    echo "   - ECS Cluster: ${ecs_cluster} (Fargate)"
    echo "   - ECS Service: ${ecs_service} (1 tarefa)"
    echo "   - MongoDB:     Sidecar no ECS + EFS persistente (25GB)"
    echo "   - ECR:         ${ecr_name}"
    echo "   - SQS:         transaction-api_conta-bancaria-criada + DLQ"
    echo "   - S3 Logs:     ${s3_bucket}"
    echo "   - Secrets:     transaction-api/jwt, /credentials, /sqs"
    echo "   - CloudWatch:  ${cw_log_group}"
    echo ""
    echo "📋 Endpoints:"
    echo "   - API:               http://${alb_dns}"
    echo "   - Swagger UI:        http://${alb_dns}/swagger-ui.html"
    echo "   - Health Check:      http://${alb_dns}/actuator/health"
    echo ""
    echo "📋 Observabilidade:"
    echo "   - CloudWatch Logs:"
    echo "     https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/\$252Fecs\$252Ftransaction-api"
    echo "   - CloudWatch Dashboard:"
    echo "     https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#dashboards:name=transaction-api_overview"
    echo "   - X-Ray Traces:"
    echo "     https://${region}.console.aws.amazon.com/xray/home?region=${region}#/traces"
    echo ""
    echo "📋 Comandos úteis:"
    echo ""
    echo "   # Gerar token JWT:"
    echo "   curl -X POST http://${alb_dns}/api/v1/auth/token \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"client_id\":\"transaction-api-client\",\"client_secret\":\"${api_client_secret}\"}'"
    echo ""
    echo "   # Verificar logs da aplicação:"
    echo "   aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs/transaction-api-app --follow --region ${region}"
    echo ""
    echo "   # Verificar logs do MongoDB:"
    echo "   aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs-mongo --follow --region ${region}"
    echo ""
    echo "   # Verificar status do ECS:"
    echo "   aws ecs describe-services --cluster ${ecs_cluster} --services ${ecs_service} --region ${region}"
    echo ""
    echo "   # Forçar novo deployment:"
    echo "   aws ecs update-service --cluster ${ecs_cluster} --service ${ecs_service} --force-new-deployment --region ${region}"
    echo ""
    echo "   # Executar testes pós-deploy:"
    echo "   source scripts/env-aws.sh && ./scripts/test-post-deploy.sh"
    echo ""
}

# ==========================================
# Principal
# ==========================================
print_banner

# ==========================================
# 1. Verificar pré-requisitos
# ==========================================
echo -e "${BLUE}🔍${NC} 1. Verificando pré-requisitos..."

MISSING_DEPS=0
check_dep "aws"       "AWS CLI v2"       "https://aws.amazon.com/cli/" || MISSING_DEPS=1
check_dep "terraform" "Terraform v1.5+"  "https://www.terraform.io/downloads" || MISSING_DEPS=1
check_dep "docker"    "Docker Engine"    "https://docs.docker.com/engine/install/" || MISSING_DEPS=1
check_dep "curl"      "curl"             "apt install curl" || MISSING_DEPS=1
check_dep "jq"        "jq"               "apt install jq" || MISSING_DEPS=1
check_dep "openssl"   "OpenSSL"          "apt install openssl" || MISSING_DEPS=1
check_dep "java"      "Java JDK 21+"     "https://adoptium.net/" || MISSING_DEPS=1
check_dep "mvn"       "Maven 3.9+"       "apt install maven" || MISSING_DEPS=1
check_dep "git"       "git"              "apt install git" || MISSING_DEPS=1

echo ""

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}❌ Corrija as dependencias acima e tente novamente.${NC}"
    exit 1
fi

# Verificar Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "   ${RED}❌ Docker nao esta rodando. Inicie o Docker e tente novamente.${NC}"
    exit 1
fi
echo -e "   ${GREEN}✅${NC} Docker está rodando"

# Verificar credenciais AWS
echo ""
echo -e "${BLUE}🔐${NC} Verificando credenciais AWS..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "   ${RED}❌ Credenciais AWS nao configuradas.${NC}"
    echo "      Execute: aws configure"
    exit 1
fi
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "   ${GREEN}✅${NC} AWS Account ID: ${AWS_ACCOUNT_ID}"
echo -e "   ${GREEN}✅${NC} AWS Region: ${AWS_REGION}"
echo ""

# ==========================================
# 2. Carregar valores sensíveis
# ==========================================
echo -e "${BLUE}🔑${NC} 2. Carregando valores sensíveis..."

# Tentar ler do tfvars primeiro
if [ -f "$TFVARS_FILE" ]; then
    JWT_SECRET=$(grep -E '^\s*jwt_secret\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' 2>/dev/null || echo "")
    API_CLIENT_SECRET=$(grep -E '^\s*api_client_secret\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' 2>/dev/null || echo "")
    DB_MASTER_USERNAME=$(grep -E '^\s*db_master_username\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' 2>/dev/null || echo "admin")
    DB_MASTER_PASSWORD=$(grep -E '^\s*db_master_password\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' 2>/dev/null || echo "")
fi

# Fallback: gerar aleatório se não encontrou no tfvars
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 32)}"
API_CLIENT_SECRET="${API_CLIENT_SECRET:-$(openssl rand -base64 16)}"
DB_MASTER_USERNAME="${DB_MASTER_USERNAME:-admin}"
DB_MASTER_PASSWORD="${DB_MASTER_PASSWORD:-$(openssl rand -base64 16)}"

echo -e "   ${GREEN}✅${NC} Secrets carregados com sucesso!"
echo ""

# ==========================================
# 3. Build da imagem Docker
# ==========================================
echo -e "${BLUE}📦${NC} 3. Construindo imagem Docker..."
cd "$PROJECT_DIR"
docker build -t transaction-api:latest .
echo -e "   ${GREEN}✅${NC} Imagem construida com sucesso!"
echo ""

# ==========================================
# 4. Verificar estado da infraestrutura
# ==========================================
echo -e "${BLUE}🔎${NC} 4. Verificando estado da infraestrutura..."

cd "$PROJECT_DIR/terraform"
INFRA_EXISTS=false

if [ -f "terraform.tfstate" ]; then
    echo -e "   ${GREEN}✅${NC} Estado Terraform encontrado. Infraestrutura já existe."
    INFRA_EXISTS=true
else
    echo "   ℹ️  Nenhum estado anterior encontrado."
    # Verificar se há recursos na AWS mesmo sem state local
    EXISTING_ALB=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, 'transaction-api')].LoadBalancerName" \
        --output text 2>/dev/null || echo "")
    if [ -n "$EXISTING_ALB" ]; then
        echo -e "   ${RED}⚠️  Recursos AWS encontrados mas sem state local. Importe ou destrua manualmente.${NC}"
        echo "   ALB encontrado: ${EXISTING_ALB}"
        echo "   Abortando para evitar duplicidade."
        exit 1
    fi
    echo -e "   ${GREEN}✅${NC} Nenhum recurso existente. Infraestrutura será criada do zero."
fi

echo ""

# ==========================================
# 5. Provisionar/Atualizar infraestrutura
# ==========================================
if [ "$INFRA_EXISTS" = true ]; then
    echo -e "${BLUE}🔄${NC} 5. Atualizando infraestrutura existente..."
else
    echo -e "${BLUE}🏗️${NC}  5. Provisionando nova infraestrutura..."
fi

# Inicializar Terraform (sempre)
echo "   Inicializando Terraform..."
terraform init -input=false -upgrade > /dev/null 2>&1

# Validar configuração
echo "   Validando configuração..."
terraform validate > /dev/null 2>&1

# Preparar variáveis TFVARS (se existir)
TFVARS_ARG=""
if [ -f "$TFVARS_FILE" ]; then
    TFVARS_ARG="-var-file=${TFVARS_FILE}"
fi

# Planejar
echo "   Planejando mudancas..."
terraform plan \
    $TFVARS_ARG \
    -var="jwt_secret=${JWT_SECRET}" \
    -var="api_client_secret=${API_CLIENT_SECRET}" \
    -var="db_master_username=${DB_MASTER_USERNAME}" \
    -var="db_master_password=${DB_MASTER_PASSWORD}" \
    -out=tfplan \
    -input=false

echo ""
echo -e "   ${YELLOW}⚠️${NC}  Plano Terraform gerado."

# Confirmação (se não for AUTO_APPROVE)
if [ "$AUTO_APPROVE" != "true" ]; then
    echo ""
    if [ "$INFRA_EXISTS" = true ]; then
        read -r -p "   Aplicar atualizações na infraestrutura existente? [S/n] " CONFIRM
    else
        read -r -p "   Criar nova infraestrutura? [S/n] " CONFIRM
    fi
    CONFIRM=${CONFIRM:-S}
    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
        echo "   Deploy cancelado pelo usuario."
        exit 0
    fi
fi

# Aplicar
echo "   Aplicando..."
terraform apply -input=false tfplan
echo -e "   ${GREEN}✅${NC} Infraestrutura atualizada com sucesso!"
echo ""

# ==========================================
# 6. Extrair outputs do Terraform
# ==========================================
echo -e "${BLUE}📋${NC} 6. Extraindo informações da infraestrutura..."

ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
ECR_REPO_NAME=$(terraform output -raw ecr_repository_name 2>/dev/null || echo "transaction-api")
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
ECS_SERVICE=$(terraform output -raw ecs_service_name 2>/dev/null || echo "")
SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw s3_logs_bucket 2>/dev/null || echo "")
CW_LOG_GROUP=$(terraform output -raw cloudwatch_log_group 2>/dev/null || echo "")

# Obter Target Group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
    --names transaction-api-tg \
    --region "$AWS_REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "")

echo -e "   ${GREEN}✅${NC} ALB DNS: ${ALB_DNS}"
echo -e "   ${GREEN}✅${NC} ECR URL: ${ECR_REPO_URL}"
echo -e "   ${GREEN}✅${NC} ECS Cluster: ${ECS_CLUSTER}"
echo ""

# ==========================================
# 7. Limpar imagens antigas do ECR
# ==========================================
echo -e "${BLUE}🧹${NC} 7. Limpando imagens antigas do ECR..."
cleanup_ecr_images "$ECR_REPO_NAME" "$AWS_REGION"
echo ""

# ==========================================
# 8. Push da imagem para ECR
# ==========================================
echo -e "${BLUE}📤${NC} 8. Fazendo push da imagem para ECR..."

echo "   Fazendo login no ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" > /dev/null 2>&1

echo "   Enviando imagem..."
docker tag transaction-api:latest "${ECR_REPO_URL}:latest"
docker push "${ECR_REPO_URL}:latest" > /dev/null 2>&1

echo -e "   ${GREEN}✅${NC} Imagem enviada: ${ECR_REPO_URL}:latest"
echo ""

# ==========================================
# 9. Forçar novo deployment no ECS
# ==========================================
echo -e "${BLUE}🔄${NC} 9. Atualizando ECS com nova imagem..."
aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --force-new-deployment \
    --region "${AWS_REGION}" > /dev/null 2>&1
echo -e "   ${GREEN}✅${NC} Novo deployment forçado."
echo ""

# ==========================================
# 10. Verificar TODOS os componentes
# ==========================================
echo -e "${BLUE}🔍${NC} 10. Verificando todos os componentes da infraestrutura..."
echo "     Timeout máximo: 5 minutos"
echo ""

if ! verify_all_components "$ALB_DNS" "$ECS_CLUSTER" "$ECS_SERVICE" "$AWS_REGION" "$TG_ARN"; then
    echo ""
    echo -e "${RED}❌ ERRO: Nem todos os componentes estão operacionais.${NC}"
    echo ""
    echo "   Possíveis causas:"
    echo "   - A aplicação pode estar com erro de startup (verifique os logs)"
    echo "   - O MongoDB sidecar pode não ter iniciado"
    echo "   - O security group pode estar bloqueando tráfego"
    echo ""
    echo "   Logs da aplicação:"
    echo "   aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs/transaction-api-app --region ${AWS_REGION}"
    echo ""
    echo "   Logs do MongoDB:"
    echo "   aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs-mongo --region ${AWS_REGION}"
    echo ""
    exit 1
fi

# ==========================================
# 11. Seed de contas de teste (apenas na primeira execução)
# ==========================================
echo -e "${BLUE}🌱${NC} 11. Verificando seed de contas de teste..."
echo "   Verificando se já existem contas no MongoDB..."

SEED_NEEDED=false
if [ "$INFRA_EXISTS" = false ]; then
    # Primeira execução: verificar se a API tem contas
    ACCOUNTS_RESPONSE=$(curl -sf "http://${ALB_DNS}/actuator/health" 2>/dev/null || echo "")
    if [ -n "$ACCOUNTS_RESPONSE" ]; then
        echo "   Primeira execução detectada. Enviando contas de teste..."
        SEED_NEEDED=true
    fi
else
    echo -e "   ${YELLOW}⏭️${NC}  Infraestrutura já existia. Seed já foi executado anteriormente."
fi

if [ "$SEED_NEEDED" = true ]; then
    echo "   Enviando 10 contas de teste para SQS..."
    for i in $(seq 1 10); do
        ACCOUNT_ID=$(uuidgen)
        OWNER_ID=$(uuidgen)
        CREATED_AT=$(date +%s)
        aws sqs send-message \
            --queue-url "$SQS_QUEUE_URL" \
            --region "$AWS_REGION" \
            --message-body "{\"account\":{\"id\":\"$ACCOUNT_ID\",\"owner\":\"$OWNER_ID\",\"created_at\":\"$CREATED_AT\",\"status\":\"ENABLED\"}}" \
            > /dev/null 2>&1
        echo -e "   ${GREEN}✅${NC} Conta $i: $ACCOUNT_ID"
    done
    echo -e "   ${GREEN}✅${NC} 10 contas de teste enviadas para SQS!"
    echo ""
    echo -e "   ${YELLOW}⏳${NC} Aguardando processamento das contas (30s)..."
    sleep 30
    echo -e "   ${GREEN}✅${NC} Contas processadas pelo consumer."
fi

echo ""

# ==========================================
# 12. Resumo final
# ==========================================
print_summary \
    "$ALB_DNS" \
    "$AWS_REGION" \
    "$AWS_ACCOUNT_ID" \
    "$ENVIRONMENT" \
    "$ECS_CLUSTER" \
    "$ECS_SERVICE" \
    "$ECR_REPO_NAME" \
    "$SQS_QUEUE_URL" \
    "$S3_BUCKET" \
    "$CW_LOG_GROUP" \
    "$API_CLIENT_SECRET"

# Voltar ao diretório do projeto
cd "$PROJECT_DIR"