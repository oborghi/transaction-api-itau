#!/bin/bash
set -e

# ==========================================
# Transaction API - Deploy para AWS
# ==========================================
# Este script realiza o deploy completo da aplicação em producao na AWS:
#   1. Verifica pré-requisitos (AWS CLI, Terraform, Docker, kubectl)
#   2. Build da imagem Docker
#   3. Provisionamento da infraestrutura com Terraform
#      (VPC, DocumentDB, SQS, Secrets Manager, ALB, ECS Fargate)
#   4. Push da imagem para ECR
#   5. Deploy no ECS Fargate
#   6. Verificacao de saude da API
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_DEFAULT_REGION:-sa-east-1}"
TFVARS_FILE="environments/${ENVIRONMENT}.tfvars"

echo "☁️  =========================================="
echo "   Deploy AWS - Transaction API"
echo "   Ambiente: ${ENVIRONMENT}"
echo "   Regiao:   ${AWS_REGION}"
echo "=========================================="
echo ""

# ==========================================
# 1. Verificar pre-requisitos
# ==========================================
echo "🔍 1. Verificando pre-requisitos..."

MISSING_DEPS=0

if ! command -v aws &> /dev/null; then
    echo "   ❌ AWS CLI nao encontrado. Instale: https://aws.amazon.com/cli/"
    MISSING_DEPS=1
fi

if ! command -v terraform &> /dev/null; then
    echo "   ❌ Terraform nao encontrado. Instale: https://www.terraform.io/downloads"
    MISSING_DEPS=1
fi

if ! command -v docker &> /dev/null; then
    echo "   ❌ Docker nao encontrado. Instale: https://docs.docker.com/get-docker/"
    MISSING_DEPS=1
fi

if ! command -v kubectl &> /dev/null; then
    echo "   ⚠️  kubectl nao encontrado (recomendado para verificacao do EKS)."
    echo "      Instale: https://kubernetes.io/docs/tasks/tools/"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo "❌ Corrija as dependencias acima e tente novamente."
    exit 1
fi

# Verificar se Docker esta rodando
if ! docker info > /dev/null 2>&1; then
    echo "   ❌ Docker nao esta rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# Verificar se credenciais AWS estao configuradas
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "   ❌ Credenciais AWS nao configuradas."
    echo "      Configure com: aws configure"
    echo "      Ou use: export AWS_PROFILE=<seu-profile>"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region 2>/dev/null || echo "$AWS_REGION")

echo "   ✅ AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "   ✅ AWS Region: ${AWS_REGION}"
echo "   ✅ Todos os pre-requisitos atendidos!"
echo ""

# ==========================================
# 2. Build da imagem Docker
# ==========================================
echo "📦 2. Construindo imagem Docker..."

cd "$PROJECT_DIR"

docker build -t transaction-api:latest .

if [ $? -ne 0 ]; then
    echo "   ❌ Falha no build da imagem Docker."
    exit 1
fi

echo "   ✅ Imagem construida com sucesso!"
echo ""

# ==========================================
# 3. Provisionar infraestrutura com Terraform
# ==========================================
echo "🏗️  3. Provisionando infraestrutura com Terraform..."
echo "   Ambiente: ${ENVIRONMENT}"

cd "$PROJECT_DIR/terraform"

# Inicializar Terraform
echo "   Inicializando Terraform..."
terraform init -input=false

if [ $? -ne 0 ]; then
    echo "   ❌ Falha na inicializacao do Terraform."
    exit 1
fi

# Planejar mudancas
echo "   Planejando mudancas..."
terraform plan \
    -var-file="$TFVARS_FILE" \
    -out=tfplan \
    -input=false

if [ $? -ne 0 ]; then
    echo "   ❌ Falha no planejamento do Terraform."
    echo "   Verifique as variaveis em ${TFVARS_FILE}"
    exit 1
fi

echo ""
echo "   ⚠️  Plano Terraform gerado. Revise as mudancas acima."
echo "   Para aplicar automaticamente, pressione ENTER ou cancele com Ctrl+C."
read -r -p "   Aplicar plano? [S/n] " CONFIRM
CONFIRM=${CONFIRM:-S}

if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "   Deploy cancelado pelo usuario."
    exit 0
fi

# Aplicar mudancas
echo "   Aplicando infraestrutura..."
terraform apply \
    -input=false \
    tfplan

if [ $? -ne 0 ]; then
    echo "   ❌ Falha na aplicacao do Terraform."
    exit 1
fi

echo "   ✅ Infraestrutura provisionada com sucesso!"
echo ""

# ==========================================
# 4. Push da imagem para ECR
# ==========================================
echo "📤 4. Fazendo push da imagem para ECR..."

# Obter URL do ECR a partir do Terraform
ECR_REPO_NAME=$(terraform output -raw ecr_repository_name 2>/dev/null || echo "transaction-api")
ECR_REGION="${AWS_REGION}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com/${ECR_REPO_NAME}"

# Login no ECR
echo "   Fazendo login no ECR..."
aws ecr get-login-password --region "${ECR_REGION}" | \
    docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "   ❌ Falha no login do ECR."
    exit 1
fi

# Tag e push da imagem
echo "   Enviando imagem para ECR..."
docker tag transaction-api:latest "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"

if [ $? -ne 0 ]; then
    echo "   ❌ Falha no push da imagem para ECR."
    exit 1
fi

echo "   ✅ Imagem enviada para ECR: ${ECR_URI}:latest"
echo ""

# ==========================================
# 5. Forcar novo deployment no ECS
# ==========================================
echo "🔄 5. Forcando novo deployment no ECS..."

ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "transaction-api-cluster")
ECS_SERVICE=$(terraform output -raw ecs_service_name 2>/dev/null || echo "transaction-api-service")

aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --force-new-deployment \
    --region "${ECR_REGION}" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "   ✅ Novo deployment forcado no ECS."
else
    echo "   ⚠️  Nao foi possivel forcar deployment (pode ser normal na primeira execucao)."
fi
echo ""

# ==========================================
# 6. Aguardar infraestrutura ficar pronta
# ==========================================
echo "⏳ 6. Aguardando infraestrutura ficar pronta..."
echo "   DocumentDB pode levar ~10 minutos para ficar disponivel."
echo ""

MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Verificar status do ECS
    TASKS_RUNNING=$(aws ecs describe-services \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --region "${ECR_REGION}" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")

    if [ "$TASKS_RUNNING" -gt 0 ]; then
        echo "   ✅ ECS service com ${TASKS_RUNNING} task(s) rodando!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   ⏳ Tentativa $RETRY_COUNT/$MAX_RETRIES - Tasks rodando: $TASKS_RUNNING"
    sleep 15
done

if [ "$TASKS_RUNNING" -eq 0 ]; then
    echo "   ⚠️  ECS service nao ficou pronto apos ${MAX_RETRIES} tentativas."
    echo "   Verifique os logs no CloudWatch."
fi
echo ""

# ==========================================
# 7. Verificar saude da API
# ==========================================
echo "🏥 7. Verificando saude da API..."

ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")

if [ "$ALB_DNS" = "N/A" ] || [ -z "$ALB_DNS" ]; then
    echo "   ⚠️  Nao foi possivel obter o DNS do ALB."
    echo "   Verifique manualmente com: terraform output"
else
    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -sf "http://${ALB_DNS}/actuator/health" > /dev/null 2>&1; then
            echo "   ✅ API esta saudavel em http://${ALB_DNS}"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   ⏳ Tentativa $RETRY_COUNT/$MAX_RETRIES..."
        sleep 10
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "   ⚠️  API nao ficou saudavel apos $MAX_RETRIES tentativas."
        echo "   Verifique os logs no CloudWatch."
    fi
fi
echo ""

# ==========================================
# 8. Resumo do deploy
# ==========================================
echo "=========================================="
echo "✅ Deploy AWS concluido com sucesso!"
echo "=========================================="
echo ""
echo "📋 Resumo:"
echo "   - Ambiente:    ${ENVIRONMENT}"
echo "   - Regiao:      ${AWS_REGION}"
echo "   - Account ID:  ${AWS_ACCOUNT_ID}"
echo "   - ECR URI:     ${ECR_URI}"
echo "   - ECS Cluster: ${ECS_CLUSTER}"
echo "   - ECS Service: ${ECS_SERVICE}"
echo ""
echo "📋 Endpoints:"
echo "   - API:           http://${ALB_DNS}"
echo "   - Swagger UI:    http://${ALB_DNS}/swagger-ui.html"
echo "   - Health Check:  http://${ALB_DNS}/actuator/health"
echo ""
echo "📋 Comandos uteis:"
echo ""
echo "   # Gerar token JWT:"
echo "   curl -X POST http://${ALB_DNS}/api/v1/auth/token \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"client_id\":\"transaction-api-client\",\"client_secret\":\"super-secret-key-123\"}'"
echo ""
echo "   # Verificar logs:"
echo "   aws logs tail /ecs/transaction-api --follow --region ${AWS_REGION}"
echo ""
echo "   # Verificar status do ECS:"
echo "   aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --region ${AWS_REGION}"
echo ""
echo "   # Verificar fila SQS:"
echo "   aws sqs get-queue-attributes \\"
echo "     --queue-url \$(terraform output -raw sqs_queue_url) \\"
echo "     --attribute-names All --region ${AWS_REGION}"
echo ""
echo "   # Verificar DocumentDB:"
echo "   aws docdb describe-db-clusters --region ${AWS_REGION}"
echo ""
echo "   # Verificar Secrets Manager:"
echo "   aws secretsmanager list-secrets --region ${AWS_REGION} --query 'SecretList[?starts_with(Name, \`transaction-api\`)].Name'"
echo ""
echo "   # Verificar variaveis Terraform:"
echo "   cd terraform && terraform output"
echo ""
echo "   # Destruir ambiente:"
echo "   cd terraform && terraform destroy -var-file=${TFVARS_FILE}"
echo ""
echo "   # Forcar novo deployment:"
echo "   aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment --region ${AWS_REGION}"
echo ""

# Voltar ao diretorio do projeto
cd "$PROJECT_DIR"