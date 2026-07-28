#!/bin/bash
set -e

echo "☁️  Iniciando ambiente AWS..."
echo "   - Amazon DocumentDB (MongoDB)"
echo "   - Amazon SQS"
echo "   - AWS Secrets Manager"
echo "   - Transaction API (ECS Fargate)"
echo ""

# Verifica se AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale o AWS CLI."
    exit 1
fi

# Verifica se Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não encontrado. Instale o Terraform."
    exit 1
fi

# Verifica se Docker está instalado (para build da imagem)
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# Verifica se as credenciais AWS estão configuradas
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Credenciais AWS não configuradas. Configure com: aws configure"
    exit 1
fi

echo "✅ Pré-requisitos verificados!"
echo ""

# ==========================================
# 1. Build da imagem Docker
# ==========================================
echo "📦 1. Construindo imagem Docker..."
docker build -t transaction-api:latest .
echo "   ✅ Imagem construída com sucesso!"
echo ""

# ==========================================
# 2. Push para ECR
# ==========================================
echo "📤 2. Fazendo push da imagem para ECR..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_DEFAULT_REGION:-sa-east-1}
ECR_REPO="transaction-api"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# Login no ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Tag e push
docker tag transaction-api:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
echo "   ✅ Imagem enviada para ECR: ${ECR_URI}:latest"
echo ""

# ==========================================
# 3. Deploy com Terraform
# ==========================================
echo "🏗️  3. Deployando com Terraform..."
cd terraform

# Inicializar Terraform
terraform init

# Planejar
terraform plan -var-file=environments/dev.tfvars -out=tfplan

# Aplicar
terraform apply tfplan

echo "   ✅ Deploy concluído com sucesso!"
echo ""

# ==========================================
# 4. Obter informações do deploy
# ==========================================
echo "📋 4. Informações do deploy:"
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
echo "   - ALB DNS: ${ALB_DNS}"
echo "   - API URL: http://${ALB_DNS}"
echo ""

# ==========================================
# 5. Verificar saúde da API
# ==========================================
echo "🏥 5. Verificando saúde da API..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf "http://${ALB_DNS}/actuator/health" > /dev/null 2>&1; then
        echo "   ✅ API está saudável!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   ⏳ Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "   ⚠️  API não ficou saudável após $MAX_RETRIES tentativas."
    echo "   Verifique os logs no CloudWatch."
fi

echo ""
echo "✅ Ambiente AWS iniciado com sucesso!"
echo ""
echo "📋 Para gerar um token de autenticação:"
echo "   curl -X POST http://${ALB_DNS}/api/v1/auth/token \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"client_id\":\"transaction-api-client\",\"client_secret\":\"super-secret-key-123\"}'"
echo ""
echo "📋 Para verificar a fila SQS:"
echo "   aws sqs get-queue-attributes --queue-url https://sqs.${AWS_REGION}.amazonaws.com/${AWS_ACCOUNT_ID}/conta-bancaria-criada --attribute-names All"
echo ""
echo "📋 Para verificar logs:"
echo "   aws logs tail /ecs/transaction-api --follow"
echo ""
echo "📋 Para destruir o ambiente:"
echo "   cd terraform && terraform destroy -var-file=environments/dev.tfvars"