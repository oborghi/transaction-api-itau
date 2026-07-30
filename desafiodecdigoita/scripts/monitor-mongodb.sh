#!/bin/bash
# ==========================================
# Monitor MongoDB EC2 Setup
# ==========================================
# Usa AWS internamente (SSM + CloudWatch) em vez
# de conexão direta à porta 27017, contornando
# possíveis bloqueios de NAT/firewall do provedor
# ==========================================

set -e

INSTANCE_ID="i-00abae1cad5ffb169"
REGION="sa-east-1"
EIP="18.231.32.73"

echo "======================================"
echo "  Monitor MongoDB EC2"
echo "======================================"
echo "Instância: $INSTANCE_ID"
echo "EIP: $EIP"
echo "Private IP: 10.0.0.126"
echo "======================================"
echo ""

echo "[1/5] Verificando estado da instância..."
STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].State.Name' --output text)
echo "  Estado: $STATE"
echo ""

echo "[2/5] Verificando system logs (console output)..."
CONSOLE=$(aws ec2 get-console-output --instance-id "$INSTANCE_ID" \
  --region "$REGION" --query 'Output' --output text 2>/dev/null)
echo "  Cloud-init status:"
echo "$CONSOLE" | grep -E "(cloud-init.*finished|scripts-user|Failed)" | tail -3 || echo "  (ainda a processar...)"
echo ""

echo "[3/5] Verificando LastKnownAwsPrivateIpAddress no CloudWatch Agent (diagnóstico)..."
echo "  (não aplicável - sem CloudWatch Agent na EC2)"
echo ""

echo "[4/5] Testando conectividade via System Manager Session Manager (se disponível)..."
echo "  Tentando SSM..."
SSM_STATE=$(aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --region "$REGION" \
  --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
if [ "$SSM_STATE" = "Online" ]; then
  echo "  ✅ SSM Online! Executando diagnóstico remoto..."
  aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["cat /tmp/user_data.log 2>/dev/null | tail -20"]' \
    --region "$REGION" \
    --query 'Command.CommandId' --output text 2>/dev/null
else
  echo "  ⚠️  SSM não disponível (PingStatus: $SSM_STATE)"
  echo "  (Normal se não configurou IAM role para SSM na EC2)"
fi
echo ""

echo "[5/5] Verificando se o Docker responde localmente..."
echo "  Testando porta 27017 na instância via VPC (recomendado usar um container helper)"
echo ""
echo "  🔍 Usando o próprio ALB como referência indireta:"
ALB_DNS="transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com"
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
  "http://$ALB_DNS/actuator/health" 2>/dev/null || echo "000")
if [ "$HEALTH_CHECK" = "200" ]; then
  echo "  ✅ ALB respondendo! Código: $HEALTH_CHECK"
  echo "  ⏩ Aplicação no ar!"
else
  echo "  ⚠️  ALB: Código $HEALTH_CHECK (ainda a provisioning...)"
fi
echo ""

echo "======================================"
echo "  Diagnóstico resumido:"
echo "======================================"
echo ""
echo "  MongoDB EC2:          $STATE"
echo "  ALB Health Check:     $HEALTH_CHECK"
echo ""
echo "  ⏳ A EC2 demora ~2-3 minutos para instalar"
echo "     Docker e puxar a imagem mongo:7.0"
echo ""
echo "  💡 Dica: Para ver logs reais da EC2:"
echo "    1. Acesse o console AWS > EC2 > Instâncias"
echo "    2. Selecione a instância: $INSTANCE_ID"
echo "    3. Actions > Monitor and troubleshoot >"
echo "        Get system log"
echo ""
echo "  📋 Ou aguarde e reexecute este script:"
echo "     bash scripts/monitor-mongodb.sh"
echo "======================================"