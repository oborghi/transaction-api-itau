# 🏦 Transaction API - Autorização de Transações Financeiras

[![CI Pipeline](https://github.com/ocborghi/desafiodecdigoita/actions/workflows/ci.yml/badge.svg)](https://github.com/ocborghi/desafiodecdigoita/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/badge/coverage-%E2%89%A580%25-brightgreen)]()

API REST para autorização de transações financeiras, construída com **Kotlin + Spring Boot 3.3**, seguindo arquitetura **Domain Driven Design (DDD)** com padrões de resiliência (Circuit Breaker, Dead Letter Queue, Retry).

## 📋 Table of Contents

- [Sistemas Suportados](#sistemas-suportados)
- [Pré-requisitos](#pré-requisitos)
- [Visão Geral](#visão-geral)
- [Arquitetura AWS](#arquitetura-aws)
- [Scripts de Execução](#scripts-de-execução)
- [Ambiente Dev AWS (Produção)](#ambiente-dev-aws-produção)
- [Endpoints da API](#endpoints-da-api)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Padrões de Resiliência](#padrões-de-resiliência)
- [Testes](#testes)
- [Deploy na AWS](#deploy-na-aws)
- [CI/CD](#cicd)
- [Observabilidade](#observabilidade)
- [Decisões Arquiteturais](#decisões-arquiteturais)

---

## Sistemas Suportados

| Sistema | Suporte | Observação |
|---------|---------|------------|
| **Linux** (Ubuntu, Debian, Fedora, etc.) | ✅ Suportado | Nativo |
| **macOS** | ✅ Suportado | Via Docker Desktop |
| **Windows** | ✅ Suportado | **Apenas via WSL2** (Windows Subsystem for Linux) |

> ⚠️ **Windows:** Os scripts shell (.sh) **não funcionam** no CMD ou PowerShell. Execute-os dentro do **WSL2**.

---

## Pré-requisitos

### Ferramentas Obrigatórias

| Ferramenta | Versão Mínima | Comando de Verificação |
|------------|---------------|------------------------|
| **Docker** | 24+ | `docker --version` |
| **Docker Compose** | v2 | `docker compose version` |
| **Java JDK** | 21+ | `java -version` |
| **Maven** | 3.9+ | `mvn -version` |
| **AWS CLI** | 2+ | `aws --version` |
| **Terraform** | 1.5+ | `terraform --version` |
| **curl** | Qualquer | `curl --version` |
| **jq** | Qualquer | `jq --version` |
| **openssl** | Qualquer | `openssl version` |

### Verificação Rápida

```bash
docker --version        # Docker 24+
docker compose version  # Docker Compose v2+
java -version           # OpenJDK 21+
mvn -version            # Maven 3.9+
aws --version           # AWS CLI 2+
terraform --version     # Terraform 1.5+
```

---

## Visão Geral

Sistema de autorização de transações financeiras que:

1. **Registra contas** recebendo mensagens de uma fila SQS (abertura de contas)
2. **Autoriza transações** (crédito/débito) via REST API
3. **Garante resiliência** com Circuit Breaker, Dead Letter Queue e Retry
4. **Configuração via Secrets Manager** — credenciais e URIs são carregadas do AWS Secrets Manager
5. **Arquitetura AWS Free Tier** — ECS Fargate (2 tasks) + MongoDB + EFS + ALB + SQS + Service Discovery

---

## Arquitetura AWS

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets"
                ALB["ALB<br/>HTTP:80"]
                
                subgraph "ECS Task - MongoDB"
                    MONGO["mongodb:7.0<br/>Port 27017"]
                    EFS_MONGO["EFS<br/>MongoDB /data/db"]
                end

                subgraph "ECS Task - App"
                    APP["transaction-api-app<br/>Port 8080"]
                end
                
                SD["Service Discovery<br/>mongodb.transaction-api.internal"]
            end
        end

        SQS["SQS Queue<br/>conta-bancaria-criada"]
        DLQ["SQS DLQ"]
        ECR["ECR<br/>Docker Images"]
        SM["Secrets Manager<br/>JWT, Credentials, SQS"]
        CW["CloudWatch<br/>Logs + Metrics + Dashboard"]
        S3["S3 Bucket<br/>Application Logs"]
        XR["X-Ray<br/>Distributed Tracing"]
    end

    Client["👤 Cliente"] -->|"HTTP:80"| ALB
    ALB -->|"forward"| APP
    APP -->|"mongodb.transaction-api.internal:27017"| MONGO
    MONGO -->|"/data/db"| EFS_MONGO
    MONGO -.->|"service discovery"| SD
    SD -.->|"resolve DNS"| APP
    APP --> SQS
    SQS -.->|"maxReceiveCount=5"| DLQ
    APP --> CW
    APP --> XR
    APP -.->|"lê secrets"| SM
    APP --> S3
    ECR -->|"imagem Docker"| APP
```

### Como a URI do MongoDB é resolvida

| Ambiente | Fonte | URI Resultante |
|----------|-------|----------------|
| **Local** (`run-local.sh`) | `env-local.sh` → `SPRING_DATA_MONGODB_URI` | `mongodb://admin:admin123@localhost:27017/transaction_db?authSource=admin` |
| **Docker** (`run-docker.sh`) | `docker-compose.yml` → `SPRING_DATA_MONGODB_URI` | `mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin` |
| **AWS** (`run-aws.sh`) | Task Definition → `SPRING_DATA_MONGODB_URI` | `mongodb://admin:<password>@localhost:27017/transaction_db?authSource=admin&directConnection=true` |

> 💡 Na AWS, o MongoDB roda em uma **ECS Task separada** da aplicação, acessível via Service Discovery (`mongodb.transaction-api.internal:27017`). O EFS montado em `/data/db` garante persistência mesmo com restart do container.

---

## Scripts de Execução

### `stop-all.sh` — Parar Todos os Serviços

```bash
./scripts/stop-all.sh
```

Para todos os serviços: containers Docker e processos Java.

---

### `run-local.sh` — Ambiente Local (Desenvolvimento Rápido)

```bash
./scripts/run-local.sh
```

Roda infraestrutura (LocalStack + MongoDB) em containers Docker e aplicação Java na máquina host.

**Pré-requisitos:** Docker, Java 21+, Maven

---

### `run-docker.sh` — Ambiente Docker Completo

```bash
./scripts/run-docker.sh
```

Roda **tudo** em containers Docker: aplicação, MongoDB e LocalStack (SQS, Secrets Manager, CloudWatch, X-Ray).

**Pré-requisitos:** Docker

---

### `deploy-aws.sh` — Deploy na AWS (Free Tier)

```bash
# Deploy interativo (com confirmação)
./scripts/deploy-aws.sh

# Deploy não-interativo (para CI/CD)
ENVIRONMENT=dev AUTO_APPROVE=true ./scripts/deploy-aws.sh
```

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `ENVIRONMENT` | `dev` | Ambiente: `dev` ou `staging` |
| `AUTO_APPROVE` | `false` | Se `true`, pula confirmações |
| `AWS_REGION` | `sa-east-1` | Região AWS |

**Pré-requisitos:** AWS CLI configurado + Terraform + Docker

**O que o script faz:**
1. Verifica todos os pré-requisitos
2. Carrega valores sensíveis do `environments/{env}.tfvars`
3. Build da imagem Docker
4. Provisiona infraestrutura com Terraform:
   - VPC + 2 subnets públicas + Internet Gateway
   - ALB (HTTP porta 80)
   - ECS Fargate Cluster + 2 Services (1 task para App, 1 task para MongoDB)
   - MongoDB 7.0 em task separada com EFS persistente + Service Discovery
   - ECR (repositório de imagens)
   - SQS + DLQ
   - Secrets Manager (JWT, Credentials, SQS)
   - CloudWatch Logs + Metrics + Dashboard
   - S3 (logs da aplicação)
   - IAM Roles (execução + task)
   - Security Groups (ALB, ECS, EFS)
5. Remove imagens antigas do ECR (mantém apenas a `latest`)
6. Push da imagem para ECR
7. Força novo deployment no ECS
8. **Verifica todos os componentes** (ECS, ALB targets, health API, MongoDB) com timeout de 5 minutos
9. Exibe resumo com URLs

### `env-aws.sh` — Variáveis de Ambiente AWS

```bash
source scripts/env-aws.sh
```

Carrega as variáveis de ambiente para interagir com o ambiente AWS:
- `API_URL` — URL do ALB
- `SQS_QUEUE_URL` — URL da fila SQS
- `CLOUDWATCH_ENABLED` — true
- `S3_LOG_BUCKET` — bucket de logs

### `test-post-deploy.sh` — Testes Pós-Deploy

```bash
source scripts/env-aws.sh
./scripts/test-post-deploy.sh
```

Executa bateria de 8 testes contra o ambiente AWS:
1. Health Check da API
2. Geração de Token JWT
3. Seed de contas via SQS
4. Transação CREDIT
5. Transação DEBIT (saldo suficiente)
6. Transação DEBIT (saldo insuficiente)
7. Swagger UI
8. Actuator Metrics

**Serviços AWS criados (Free Tier compatível):**
- ECS Fargate (2 tasks: App + MongoDB, 512 CPU / 1024 MB cada)
- MongoDB 7.0 (task separada via Service Discovery)
- EFS (25GB grátis) — persistência dos dados do MongoDB
- ALB (HTTP, 750h/mês grátis)
- SQS + DLQ (1M requests grátis)
- CloudWatch (10GB logs grátis)
- Secrets Manager
- S3 (5GB grátis)
- ECR
- X-Ray (100K traces grátis/mês)

---

## Ambiente Dev AWS (Produção)

O ambiente `dev` está atualmente em execução na AWS com os seguintes endpoints e recursos.

### Endpoints

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **API** | `http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com` | API principal |
| **Swagger UI** | `http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com/swagger-ui.html` | Documentação interativa |
| **Health Check** | `http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com/actuator/health` | Status da aplicação |

### Observabilidade

| Serviço | URL | Acesso |
|---------|-----|--------|
| **CloudWatch Logs** | [CloudWatch Logs - /ecs/transaction-api](https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#logsV2:log-groups/log-group/$252Fecs$252Ftransaction-api) | Requer credenciais AWS |
| **CloudWatch Dashboard** | [Dashboard - transaction-api_overview](https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#dashboards:name=transaction-api_overview) | Requer credenciais AWS |
| **X-Ray Traces** | [X-Ray - Traces](https://sa-east-1.console.aws.amazon.com/xray/home?region=sa-east-1#/traces) | Requer credenciais AWS |

> ⚠️ Os links do CloudWatch e X-Ray requerem autenticação na AWS Console com uma conta que tenha permissões de leitura (`CloudWatchReadOnlyAccess`, `AWSXrayReadOnlyAccess`).

### Comandos Úteis

```bash
# Gerar token JWT (ambiente dev)
curl -X POST http://transaction-api-alb-1776620615.sa-east-1.elb.amazonaws.com/api/v1/auth/token \
  -H 'Content-Type: application/json' \
  -d '{"client_id":"transaction-api-client","client_secret":"<api_client_secret>"}'

# Verificar logs da aplicação
aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs/transaction-api-app --follow --region sa-east-1

# Verificar logs do MongoDB
aws logs tail /ecs/transaction-api --log-stream-name-prefix ecs-mongo --follow --region sa-east-1

# Verificar status do ECS
aws ecs describe-services --cluster transaction-api_cluster --services transaction-api_service --region sa-east-1

# Forçar novo deployment
aws ecs update-service --cluster transaction-api_cluster --service transaction-api_service --force-new-deployment --region sa-east-1
```

---

## Endpoints da API

> ⚠️ Todos os endpoints (exceto `/api/v1/auth/token`) requerem header `Authorization: Bearer {JWT_TOKEN}`

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `POST` | `/api/v1/auth/token` | Gerar token JWT |
| `POST` | `/api/v1/transactions/{transactionId}` | Autorizar transação |
| `GET` | `/actuator/health` | Health check |
| `GET` | `/actuator/metrics` | Métricas da aplicação |

### Gerar Token de Autenticação

```bash
curl -X POST http://localhost:8080/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'
```

### Popular Contas de Teste (via SQS)

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=sa-east-1
./scripts/seed-accounts.sh
```

### Testar Transação

```bash
curl -X POST http://localhost:8080/api/v1/transactions/$(uuidgen) \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"account_id":"<ACCOUNT_ID>","type":"CREDIT","amount":{"value":100.00,"currency":"BRL"}}'
```

### Credenciais Padrão

| Serviço | Credenciais |
|---------|-------------|
| **API Client** | `client_id: transaction-api-client` / `client_secret: AxIp+2lLcgdYV8oVYrC15w==` |
| **API Readonly** | `client_id: transaction-api-readonly` / `client_secret: AxIp+2lLcgdYV8oVYrC15w==` |
| **MongoDB** | `admin` / senha gerada automaticamente |
| **AWS (LocalStack)** | `access_key: test` / `secret_key: test` |

### URLs de Acesso (Local/Docker)

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **API** | http://localhost:8080 | Transaction API |
| **Swagger UI** | http://localhost:8080/swagger-ui.html | Documentação interativa |
| **Health Check** | http://localhost:8080/actuator/health | Status da aplicação |
| **LocalStack** | http://localhost:4566 | AWS services (SQS, Secrets Manager, CloudWatch, S3) |

---

## Estrutura do Projeto

```
desafiodecdigoita/
├── pom.xml                          # Parent POM (multi-module)
├── Dockerfile                       # Multi-stage Docker build
├── docker-compose.yml               # Infraestrutura local (MongoDB, LocalStack, App)
├── transaction-domain/              # Domain Layer (Core)
├── transaction-application/         # Application Layer (Use Cases)
├── transaction-infrastructure/      # Infrastructure Layer (Adapters)
├── transaction-api/                 # API Layer (Controllers, Config)
├── terraform/                       # Infrastructure as Code (AWS)
│   ├── main.tf                      # Provider configuration
│   ├── variables.tf                 # Input variables
│   ├── vpc.tf                       # VPC + subnets + Internet Gateway
│   ├── ecs.tf                       # ECS Fargate cluster + services (app + mongodb tasks)
│   ├── efs.tf                       # EFS persistent storage for MongoDB
│   ├── alb.tf                       # Application Load Balancer (HTTP)
│   ├── ecr.tf                       # ECR repository
│   ├── sqs.tf                       # SQS queues + DLQ
│   ├── s3.tf                        # S3 bucket for logs
│   ├── iam.tf                       # IAM roles and policies
│   ├── secretsmanager.tf            # AWS Secrets Manager
│   ├── cloudwatch.tf                # CloudWatch logs + alarms + dashboard
│   ├── outputs.tf                   # Terraform outputs
│   └── environments/                # Environment-specific tfvars
├── scripts/                         # Scripts de Apoio
│   ├── run-local.sh                 # Ambiente local (app na máquina host)
│   ├── run-docker.sh                # Ambiente Docker completo
│   ├── deploy-aws.sh                # Deploy AWS (ECS Fargate)
│   ├── env-aws.sh                   # Variáveis de ambiente AWS
│   ├── test-post-deploy.sh          # Testes pós-deploy AWS
│   ├── init-localstack.sh           # Inicialização do LocalStack
│   ├── env-local.sh                 # Variáveis de ambiente (local)
│   ├── env-docker.sh                # Variáveis de ambiente (Docker)
│   ├── seed-accounts.sh             # Popula contas de teste no SQS
│   ├── monitor-mongodb.sh           # Monitor de conexão MongoDB
│   └── stop-all.sh                  # Para todos os serviços
└── postman/                         # Collections
```

### DDD Layers

| Módulo | Responsabilidade |
|--------|-----------------|
| `transaction-domain` | Modelos, Exceções, Ports (interfaces), Domain Services |
| `transaction-application` | DTOs, Mappers, Use Cases, Consumers |
| `transaction-infrastructure` | Repositórios, Configurações, Security, Messaging, Resiliência |
| `transaction-api` | Controllers, Exception Handlers, Configuração Spring Boot, Secrets Manager Loader |

---

## Padrões de Resiliência

### Circuit Breaker (Resilience4j)

```
CLOSED → OPEN (failureRate ≥ 50%) → HALF-OPEN (30s) → CLOSED
```

### Dead Letter Queue (DLQ)

- Mensagens que falham 5x vão para DLQ
- Reprocessador automático a cada 5 minutos
- Idempotência garantida

### Retry com Backoff

- Max 3 tentativas com backoff exponencial
- Aplicado em operações MongoDB e SQS

---

## Testes

```bash
# Todos os testes
./scripts/test.sh

# Apenas unitários
./scripts/test-unit.sh

# Apenas integração
./scripts/test-integration.sh

# Cobertura (≥80%)
./scripts/coverage.sh
```

### Pirâmide de Testes

| Camada | Quantidade | Cobertura |
|--------|------------|-----------|
| Unitários | 70 | ≥80% em todos os módulos |
| Integração | 2 | TestContainers (MongoDB) |
| E2E | Postman | Manual |

---

## Deploy na AWS

### Via Script (Recomendado)

```bash
# Deploy interativo
./scripts/deploy-aws.sh

# Deploy não-interativo (CI/CD)
ENVIRONMENT=dev AUTO_APPROVE=true ./scripts/deploy-aws.sh
```

### Via Terraform (Manual)

```bash
cd terraform
terraform init
terraform plan -var-file="environments/dev.tfvars" \
  -var="jwt_secret=$(openssl rand -base64 32)" \
  -var="api_client_secret=$(openssl rand -base64 16)" \
  -var="db_master_password=$(openssl rand -base64 16)"
terraform apply -var-file="environments/dev.tfvars" \
  -var="jwt_secret=<seu-secret>" \
  -var="api_client_secret=<seu-secret>" \
  -var="db_master_password=<sua-senha>"
```

### Pós-Deploy

```bash
# 1. Carregar variáveis de ambiente AWS
source scripts/env-aws.sh

# 2. Executar testes de verificação
./scripts/test-post-deploy.sh

# 3. (Opcional) Seed de contas adicionais
./scripts/seed-accounts.sh
```

### Serviços AWS

| Serviço | Uso | Free Tier |
|---------|-----|-----------|
| ECS Fargate | Orquestração de containers (2 tasks: App + MongoDB) | Pago por uso (~$5/mês) |
| EFS | MongoDB persistente (25GB) | ✅ 25GB grátis |
| ALB | Load balancer HTTP | ✅ 750h/mês grátis (1º ano) |
| ECR | Repositório de imagens Docker | ✅ 500MB grátis |
| SQS | Filas de mensagens | ✅ 1M requests grátis |
| S3 | Logs da aplicação | ✅ 5GB grátis |
| CloudWatch | Logs, métricas e alarmes | ✅ 10GB logs grátis |
| Secrets Manager | Gerenciamento de credenciais | $0.40/secret/mês |
| X-Ray | Tracing distribuído | ✅ 100K traces grátis/mês |

---

## Observabilidade

### CloudWatch Metrics

A aplicação exporta as seguintes métricas para CloudWatch:

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `transaction.total.count` | Counter | Total de transações processadas (dimensões: `type`, `status`) |
| `sqs.messages.consumed.count` | Counter | Mensagens SQS consumidas |
| `sqs.messages.failed.count` | Counter | Mensagens SQS com falha |
| `transaction.authorization.latency.avg` | Timer | Latência média de autorização (segundos) |
| `transaction.authorization.latency.max` | Timer | Latência máxima de autorização (segundos) |
| `account.balance.avg.value` | Gauge | Saldo médio das contas (BRL) |
| `account.total.value` | Gauge | Total de contas ativas |

### CloudWatch Dashboard

O Terraform cria automaticamente um dashboard `transaction-api_overview` com **7 widgets**:

| Widget | Tipo | Descrição |
|--------|------|-----------|
| **ECS CPU & Memory** | 📈 Métrica | CPU e Memory do ECS Fargate (últimos 5 min) |
| **ALB Request Count** | 📈 Métrica | Total de requests no Application Load Balancer |
| **Transaction API - Business Metrics** | 📈 Métrica | Transações (crédito/débito/falha), latência (avg/max), saldo médio, contas ativas, SQS consumidos/falhas |
| **SQS Queue - Messages** | 📈 Métrica | Mensagens visíveis, in-flight e deletadas |
| **SLO Compliance - Business Metrics** | 📈 Métrica | P95 Latency, Transações com falha, SQS failures |
| **SLO Alarms - Infrastructure** | 📈 Métrica | ALB 5xx errors, DLQ messages |
| **Application Logs** | 📋 Logs | Últimos 50 logs da aplicação CloudWatch |

**URL do Dashboard:**
```bash
https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#dashboards:name=transaction-api_overview
```

### SLOs (Service Level Objectives)

A aplicação, por movimentar saldo de contas bancárias 24h/dia, possui os seguintes SLOs configurados no dashboard:

| SLO | Métrica | Objetivo | Justificativa |
|-----|---------|----------|---------------|
| **SLO-1: Latência P95** | `transaction.authorization.latency.percentile` (phi=0.95) | ≤ 2s | Transações bancárias devem ser rápidas para não bloquear o fluxo do cliente |
| **SLO-2: Taxa de Falhas** | `transaction.total.count` (status=FAILED) | < 1% das transações | Sistema financeiro 24h precisa de alta confiabilidade |
| **SLO-3: DLQ Messages** | `ApproximateNumberOfMessagesVisible` (DLQ) | 0 mensagens na DLQ | Mensagens na DLQ indicam falhas não processadas que precisam de reparação |
| **SLO-4: ALB 5xx** | `HTTPCode_Target_5XX_Count` | 0 erros 5xx | Erros de servidor impactam diretamente a disponibilidade do serviço |
| **SLO-5: SQS Failures** | `sqs.messages.failed.count` | < 0.1% das mensagens | Falhas no consumo de SQS indicam problemas de processamento assíncrono |

**Alarmes (Infrastructure):**
- `transaction-api_high_cpu` — CPU > 80% por 2 períodos consecutivos de 5 min
- `transaction-api_high_memory` — Memory > 80% por 2 períodos consecutivos de 5 min

### CloudWatch Metrics Export

O export das métricas para CloudWatch é feito manualmente pelo `CloudWatchMeterRegistry` (criado em `AwsCloudWatchConfig.kt`), pois o Spring Boot 3.3.x não inclui a auto-configuração `CloudWatchMetricsExportAutoConfiguration` no `spring-boot-actuator-autoconfigure`. O registro é adicionado ao `Metrics.globalRegistry` do Micrometer, que é delegado pelo `CompositeMeterRegistry` do Actuator.

**Configuração via variáveis de ambiente:**
| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `CLOUDWATCH_ENABLED` | `false` | Habilita export de métricas para CloudWatch |
| `CLOUDWATCH_NAMESPACE` | `TransactionAPI` | Namespace no CloudWatch |
| `management.metrics.export.cloudwatch.step` | `30s` | Frequência de publicação |
| `management.metrics.export.cloudwatch.batch-size` | `20` | Tamanho do lote de publicação |

### Acesso ao CloudWatch

O acesso aos logs e dashboard do CloudWatch é feito via AWS Console com uma conta que tenha as permissões adequadas.

#### IAM User Read-Only (Criado)

Para facilitar o acesso, foi criado um IAM user `transaction-api_observability_reader` com as políticas:
- `CloudWatchReadOnlyAccess` — logs e dashboard
- `AWSXrayReadOnlyAccess` — traces do X-Ray

> ⚠️ As credenciais do IAM user foram omitidas por segurança. Para recriar:
> ```bash
> cd terraform
> terraform output -raw observability_reader_access_key_id
> terraform output -raw observability_reader_secret_access_key
> ```

**URLs diretos (requer login AWS Console):**
```bash
# Logs: https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#logsV2:log-groups/log-group/$252Fecs$252Ftransaction-api
# Dashboard: https://sa-east-1.console.aws.amazon.com/cloudwatch/home?region=sa-east-1#dashboards:name=transaction-api_overview
# X-Ray: https://sa-east-1.console.aws.amazon.com/xray/home?region=sa-east-1#/traces
```

### X-Ray Distributed Tracing

A aplicação utiliza o **AWS X-Ray SDK** para tracing distribuído:

| Span | Descrição |
|------|-----------|
| `transaction.authorize` | Autorização de transação |
| `mongodb.query` | Consultas ao banco |
| `sqs.consume` | Consumo de mensagens SQS |
| `http.server.request` | Requisições HTTP recebidas |

**Acesso ao X-Ray:** Requer a política `arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess` e pode ser acedido via:
```bash
# URL direta (requer login AWS Console):
# https://sa-east-1.console.aws.amazon.com/xray/home?region=sa-east-1#/traces
```

### Logs no S3

Os logs da aplicação são enviados para um bucket S3:
- Bucket: `transaction-api-logs-{account_id}`
- Lifecycle: 30 dias STANDARD_IA → 60 dias GLACIER → 90 dias expira

---

## Secrets Manager — Como as Credenciais São Carregadas

O `SecretsManagerLoader` é um `EnvironmentPostProcessor` do Spring Boot que carrega secrets do AWS Secrets Manager no startup da aplicação.

### Secrets Carregados

| Secret | Propriedades | Propósito |
|--------|-------------|-----------|
| `transaction-api/jwt` | `secret`, `issuer` | Chave JWT |
| `transaction-api/credentials` | `client_id`, `client_secret` | Credenciais da API |
| `transaction-api/sqs` | `region`, `queue_url`, `dlq_url` | Configuração SQS |

### Prioridade de Resolução

```
Variável de Ambiente (System.getenv) → Secrets Manager → Valor default do application.yml
```

---


## CI/CD — AWS CodePipeline (Proposto)

O pipeline de CI/CD foi migrado do GitHub Actions para **AWS CodePipeline**, aproveitando a integração nativa com os serviços AWS (ECS, ECR, CloudWatch) e permitindo blue/green deployment com zero-downtime.

### Arquitetura do Pipeline

```mermaid
graph LR
    A["GitHub<br/>Push"] --> B["CodePipeline<br/>Source"]
    B --> C["CodeBuild<br/>Test + Build"]
    C --> D["ECR<br/>Push Image"]
    D --> E["CodeDeploy<br/>Blue/Green ECS"]
    E --> F["CodeBuild<br/>Post-Deploy Tests"]
    F -->|"✅ Sucesso"| G["ECS Running<br/>New Version"]
    F -->|"❌ Falha"| H["CloudWatch Alarm<br/>Rollback"]
    H --> I["CodeDeploy<br/>Rollback"]
    I --> E
```

### Estágios do Pipeline

| Estágio | Serviço | Ação |
|---------|---------|------|
| **Source** | GitHub (Webhook) | Detecta push no branch e dispara o pipeline automaticamente |
| **Build** | AWS CodeBuild | Executa `mvn clean test package` com verificação de cobertura JaCoCo (≥ 80%) |
| **Docker Build** | AWS CodeBuild | `docker build` + `docker push` para ECR com tag `latest` e commit hash |
| **Deploy** | AWS CodeDeploy | Blue/green deployment no ECS Fargate com zero-downtime |
| **Verify** | AWS CodeBuild | Executa bateria de testes pós-deploy (health check, API, SQS, transações) |
| **Rollback** | CloudWatch Alarm | Em caso de falha, reverte automaticamente para a última versão estável |

### Variáveis de Ambiente do Pipeline

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `ENVIRONMENT` | Ambiente de deploy | `dev`, `staging`, `production` |
| `AWS_REGION` | Região AWS | `sa-east-1` |
| `ECS_CLUSTER` | Nome do cluster ECS | `transaction-api_cluster` |
| `ECS_SERVICE` | Nome do serviço ECS | `transaction-api_service` |
| `ECR_REPOSITORY` | URI do repositório ECR | `<account>.dkr.ecr.sa-east-1.amazonaws.com/transaction-api` |

### buildspec.yml (Proposto)

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto21
    commands:
      - echo "Using Java $(java -version)"
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo "Running tests and building..."
      - mvn clean test package -DskipTests=false
      - echo "Building Docker image..."
      - docker build -t $ECR_REPOSITORY:latest .
      - docker tag $ECR_REPOSITORY:latest $ECR_REPOSITORY:$IMAGE_TAG
  post_build:
    commands:
      - echo "Pushing Docker images..."
      - docker push $ECR_REPOSITORY:latest
      - docker push $ECR_REPOSITORY:$IMAGE_TAG
      - echo "Creating imagedefinitions.json..."
      - printf '[{"name":"transaction-api-app","imageUri":"%s"}]' $ECR_REPOSITORY:$IMAGE_TAG > imagedefinitions.json
artifacts:
  files: imagedefinitions.json
```

### Custo Estimado

| Serviço | Custo/mês | Observação |
|---------|-----------|------------|
| AWS CodePipeline | ~$1.00 | 1 pipeline ativo (free tier: 1 pipe grátis/mês) |
| AWS CodeBuild | ~$0.50 | 100 minutos de build/mês (free tier: 100 min/mês) |
| AWS CodeDeploy | $0.00 | Sem custo adicional para ECS |
| **Total** | **~$1.50/mês** | |

### Benefícios do CodePipeline vs GitHub Actions

| Aspecto | GitHub Actions | AWS CodePipeline |
|---------|---------------|------------------|
| **Integração AWS** | Indireta (via OIDC) | Nativa (IAM + ECR + ECS + CloudWatch) |
| **Blue/Green ECS** | Script manual | ✅ CodeDeploy nativo |
| **Rollback automático** | Custom script | ✅ Nativo via CloudWatch Alarms |
| **Custo** | Gratuito (público) | ~$1.50/mês |
| **Auditoria** | GitHub Audit Log | AWS CloudTrail |
| **IAM Permissions** | OIDC federation | Direto via IAM Roles |
| **Approval gates** | Environments | ✅ Manual approval stage nativo |

> 💡 **Recomendação**: O CodePipeline é a escolha ideal para times que já utilizam AWS como provedor de cloud, pois elimina a complexidade de gerenciar credenciais OIDC e oferece integração direta com ECS, ECR e CloudWatch para blue/green deployments e rollback automático.

---

## Decisões Arquiteturais (ADR)

| ADR | Decisão | Motivação |
|-----|---------|-----------|
| 001 | Kotlin + Spring Boot | Conciseness, null safety, coroutine support |
| 002 | MongoDB task separada + EFS + Service Discovery | Free Tier, persistência, sem EC2, manutenção isolada |
| 003 | DDD + Multi-Module | Separation of concerns, testability |
| 004 | Resilience4j | Industry standard, lightweight |
| 005 | TestContainers | Reliable integration tests |
| 006 | JaCoCo | Integrated coverage enforcement |
| 007 | ECS Fargate | Serverless containers, sem custo de control plane |
| 008 | AWS Secrets Manager | Gerenciamento seguro de credenciais |
| 009 | CloudWatch Metrics | Monitoramento nativo AWS |
| 010 | X-Ray | Tracing distribuído |
| 011 | ALB (HTTP only) | Free Tier eligible, sem necessidade de domínio |
| 012 | URI do MongoDB via Service Discovery (mongodb.transaction-api.internal) | MongoDB em task separada, comunicação via DNS |

---

## License

MIT