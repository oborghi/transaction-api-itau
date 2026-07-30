# 🏦 Transaction API - Autorização de Transações Financeiras

[ ![CI Pipeline](https://github.com/ocborghi/desafiodecdigoita/actions/workflows/ci.yml/badge.svg)](https://github.com/ocborghi/desafiodecdigoita/actions/workflows/ci.yml)
[ ![Coverage](https://img.shields.io/badge/coverage-%E2%89%A580%25-brightgreen)]()

API REST para autorização de transações financeiras, construída com **Kotlin + Spring Boot 3.3**, seguindo arquitetura **Domain Driven Design (DDD)** com padrões de resiliência (Circuit Breaker, Dead Letter Queue, Retry).

## 📋 Table of Contents

- [Sistemas Suportados](#sistemas-suportados)
- [Pré-requisitos](#pré-requisitos)
- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Scripts de Execução](#scripts-de-execução)
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

> ⚠️ **Windows:** Os scripts shell (.sh) **não funcionam** no CMD ou PowerShell. Execute-os dentro do **WSL2**. Para instalar:
> ```powershell
> wsl --install
> ```
> Após reiniciar, abra o terminal WSL (Ubuntu) e clone o repositório.

---

## Pré-requisitos

### Ferramentas Obrigatórias

| Ferramenta | Versão Mínima | Comando de Verificação | Instalação (Ubuntu/Debian) |
|------------|---------------|----------------------|---------------------------|
| **Docker** | 24+ | `docker --version` | [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) |
| **Docker Compose** | v2+ | `docker compose version` | Incluído com Docker Desktop |
| **Java JDK** | 21+ | `java -version` | `sudo apt install openjdk-21-jdk` |
| **Maven** | 3.9+ | `mvn -version` | `sudo apt install maven` |
| **AWS CLI** | 2+ | `aws --version` | [docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html](https://docs.aws.amazon.com/cli/latest/userguide/getting-started/install.html) |
| **curl** | Qualquer | `curl --version` | `sudo apt install curl` |
| **jq** | Qualquer | `jq --version` | `sudo apt install jq` |
| **GNU coreutils** | Qualquer | `uuidgen --version` | `sudo apt install uuid-runtime` (para `uuidgen`) |

### Verificação Rápida

```bash
docker --version        # Docker 24+
docker compose version  # Docker Compose v2+
java -version           # OpenJDK 21+
mvn -version            # Maven 3.9+
aws --version           # AWS CLI 2+
```

---

## Visão Geral

Sistema de autorização de transações financeiras que:

1. **Registra contas** recebendo mensagens de uma fila SQS (abertura de contas)
2. **Autoriza transações** (crédito/débito) via REST API
3. **Garante resiliência** com Circuit Breaker, Dead Letter Queue e Retry
4. **Configuração via Secrets Manager** — credenciais e URIs são carregadas do AWS Secrets Manager (ou LocalStack)
5. **Arquitetura full AWS** — DocumentDB (MongoDB compatível), SQS, CloudWatch, X-Ray, S3

---

## Arquitetura

```mermaid
graph TB
    subgraph "Application"
        API["Transaction API<br/>Spring Boot + Kotlin"]
        SM["SecretsManagerLoader<br/>EnvironmentPostProcessor"]
    end

    subgraph "AWS Services"
        SQS["SQS Queue<br/>conta-bancaria-criada"]
        DLQ["SQS DLQ"]
        DocumentDB[("DocumentDB<br/>(MongoDB Compatible)")]
        CloudWatch[("CloudWatch<br/>Metrics + Logs")]
        SecretsManager[("Secrets Manager<br/>MongoDB, JWT, SQS, Credentials")]
    end

    subgraph "Observability"
        CloudWatchG[("CloudWatch<br/>Grafana Dashboards")]
        XRay[("X-Ray<br/>Distributed Tracing")]
    end

    Client["👤 Cliente"] -->|"POST /api/v1/transactions/{id}"| API
    API --> SQS
    SQS -.->|"maxReceiveCount=5"| DLQ
    API --> DocumentDB
    API --> CloudWatch
    CloudWatch --> CloudWatchG
    API --> XRay
    API -.->|"lê secrets<br/>no startup"| SecretsManager
    SM -.->|"injeta propriedades<br/>no Environment"| API
```

### Como a URI do MongoDB é resolvida

A aplicação nunca define a URI do MongoDB no `application.yml`. A resolução segue esta ordem:

1. **Variável de ambiente** `SPRING_DATA_MONGODB_URI` — se definida, é usada diretamente
2. **AWS Secrets Manager** — se `AWS_SECRETS_ENABLED=true`, o `SecretsManagerLoader` carrega o secret `transaction-api/mongodb` e extrai a URI

| Ambiente | Fonte | URI Resultante |
|----------|-------|----------------|
| **Local** (`run-local.sh`) | `env-local.sh` → `SPRING_DATA_MONGODB_URI` | `mongodb://admin:admin123@localhost:27017/transaction_db?authSource=admin` |
| **Docker** (`run-docker.sh`) | `docker-compose.yml` → `SPRING_DATA_MONGODB_URI` | `mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin` |
| **AWS** (produção) | Secrets Manager → `transaction-api/mongodb` | Definido no secret da AWS |

**Observação:** O `SecretsManagerLoader` verifica primeiro se a variável de ambiente já existe (`System.getenv`). Se sim, o valor do secret é ignorado. Isso permite que ambientes locais/Docker sobrescrevam a URI sem precisar modificar o secret.

---

## Scripts de Execução

### `stop-all.sh` — Parar Todos os Serviços

Para todos os serviços do projeto: containers Docker e aplicação Java (se estiver rodando localmente).

```bash
./scripts/stop-all.sh
```

| Ação | Descrição |
|------|-----------|
| Mata processos Java | Para a aplicação Transaction API |
| Para containers | `docker compose down -v` (remove containers e volumes) |
| Idempotente | Pode ser chamado várias vezes sem efeitos colaterais |

---

### `run-local.sh` — Ambiente Local (Desenvolvimento Rápido)

Roda a infraestrutura (LocalStack + MongoDB) em containers Docker e a aplicação Java diretamente na máquina host.

```bash
./scripts/run-local.sh
```

| Etapa | Descrição |
|-------|-----------|
| 1. Pré-requisitos | Carrega `scripts/env-local.sh` com variáveis de ambiente |
| 2. stop-all | Para serviços anteriores |
| 3. Infraestrutura | Sobe MongoDB + LocalStack via Docker |
| 4. Init LocalStack | Executa `init-localstack.sh` (cria SQS, S3, Secrets Manager) |
| 5. Build | Compila a aplicação com Maven |
| 6. App | Roda a Transaction API com `java -cp` |

**Pré-requisitos:** Docker, Java 21+, Maven

**Variáveis de ambiente** (definidas em `scripts/env-local.sh`):
| Variável | Valor | Descrição |
|----------|-------|-----------|
| `MONGODB_HOST` | `localhost` | Host do MongoDB (LocalStack) |
| `SPRING_DATA_MONGODB_URI` | `mongodb://admin:admin123@localhost:27017/...` | URI do MongoDB |
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | Endpoint LocalStack |
| `AWS_SECRETS_ENABLED` | `true` | Habilita Secrets Manager |
| `CLOUDWATCH_ENABLED` | `true` | Habilita CloudWatch Metrics |

---

### `run-docker.sh` — Ambiente Docker Completo

Roda **tudo** em containers Docker: aplicação, MongoDB e LocalStack (SQS, Secrets Manager, CloudWatch, X-Ray).

```bash
./scripts/run-docker.sh
```

| Etapa | Descrição |
|-------|-----------|
| 1. Pré-requisitos | Verifica se Docker está rodando |
| 2. stop-all | Para serviços anteriores |
| 3. Infraestrutura | Sobe MongoDB + LocalStack via Docker |
| 4. SQS | Cria filas `conta-bancaria-criada` e DLQ |
| 5. Secrets Manager | Popula secrets (MongoDB, JWT, SQS, Credentials) |
| 6. Docker build | Constrói a imagem Docker da aplicação |
| 7. App | Sobe o container `transaction-api` |

**Pré-requisitos:** Docker

**Nota:** A URI do MongoDB é definida diretamente no `docker-compose.yml` como variável de ambiente `SPRING_DATA_MONGODB_URI`, apontando para o container `mongodb`.

---

### `run-aws.sh` — Deploy na AWS via Terraform

Faz deploy da infraestrutura e aplicação na AWS utilizando Terraform com EKS (Kubernetes).

```bash
# Deploy interativo (com confirmação)
./scripts/run-aws.sh

# Deploy não-interativo (para CI/CD)
ENVIRONMENT=staging AUTO_APPROVE=true ./scripts/run-aws.sh
```

| Variável de Ambiente | Valor Padrão | Descrição |
|---------------------|--------------|-----------|
| `ENVIRONMENT` | `dev` | Ambiente: `dev` ou `staging` |
| `AUTO_APPROVE` | `false` | Se `true`, pula confirmação (CI/CD) |
| `AWS_REGION` | `sa-east-1` | Região AWS |

**Pré-requisitos:** AWS CLI configurado + credenciais AWS + Terraform

**Serviços AWS criados:**
- EKS (Kubernetes)
- ECR (repositório de imagens)
- DocumentDB (MongoDB compatível)
- SQS + DLQ
- ALB (load balancer)
- VPC + Subnets
- IAM Roles + CloudWatch Logs + CloudWatch Metrics
- Secrets Manager (credenciais)
- X-Ray (tracing distribuído)

---

## Scripts de Apoio

### `init-localstack.sh` — Inicialização do LocalStack

Cria os recursos necessários no LocalStack: filas SQS, bucket S3 e secrets no Secrets Manager.

```bash
# Modo local (fora do container)
./scripts/init-localstack.sh

# Modo Docker (dentro do container, usa awslocal)
./scripts/init-localstack.sh --docker
```

O script aceita a variável `MONGODB_HOST` para configurar o host do MongoDB no secret:
```bash
MONGODB_HOST=localhost ./scripts/init-localstack.sh
```

### `env-local.sh` / `env-docker.sh` — Variáveis de Ambiente

Scripts para carregar configurações de ambiente:

```bash
source scripts/env-local.sh   # Desenvolvimento local
source scripts/env-docker.sh  # Docker Compose
source scripts/env-aws.sh     # Produção AWS
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
# Usar o token obtido acima e um ACCOUNT_ID do seed
curl -X POST http://localhost:8080/api/v1/transactions/$(cat /proc/sys/kernel/random/uuid) \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"account_id":"<ACCOUNT_ID>","type":"CREDIT","amount":{"value":100.00,"currency":"BRL"}}'
```

### POST `/api/v1/transactions/{transactionId}`

**Request Body:**
```json
{
  "account_id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
  "type": "CREDIT",
  "amount": {
    "value": 97.07,
    "currency": "BRL"
  }
}
```

**Response (200 OK):**
```json
{
  "transaction": {
    "id": "8e8ae808-b154-48b5-9f3e-553935cc4543",
    "type": "CREDIT",
    "amount": { "value": 97.07, "currency": "BRL" },
    "status": "SUCCEEDED",
    "timestamp": "2025-07-08T15:57:55-03:00"
  },
  "account": {
    "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
    "balance": { "amount": 183.12, "currency": "BRL" }
  }
}
```

### Credenciais Padrão

| Serviço | Credenciais |
|---------|-------------|
| **API Client** | `client_id: transaction-api-client` / `client_secret: super-secret-key-123` |
| **API Readonly** | `client_id: transaction-api-readonly` / `client_secret: super-secret-key-123` |
| **MongoDB/ DocumentDB** | `admin` / `admin123` |
| **AWS (LocalStack)** | `access_key: test` / `secret_key: test` |

### URLs de Acesso

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
├── k8s/                             # Kubernetes manifests (EKS)
├── .github/workflows/               # CI/CD
├── postman/                         # Collections
├── scripts/                         # Scripts de Apoio
│   ├── run-local.sh                 # Ambiente local (app na máquina host)
│   ├── run-docker.sh                # Ambiente Docker completo
│   ├── run-aws.sh                   # Deploy AWS
│   ├── init-localstack.sh           # Inicialização do LocalStack
│   ├── env-local.sh                 # Variáveis de ambiente (local)
│   ├── env-docker.sh                # Variáveis de ambiente (Docker)
│   ├── env-aws.sh                   # Variáveis de ambiente (AWS)
│   ├── seed-accounts.sh             # Popula contas de teste no SQS
│   ├── seed-secrets.sh              # Popula secrets no AWS (real)
│   └── stop-all.sh                  # Para todos os serviços
└── docs/                            # Documentação
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

### Terraform

```bash
cd terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Via Script

```bash
# Deploy interativo
./scripts/run-aws.sh

# Deploy não-interativo (CI/CD)
ENVIRONMENT=staging AUTO_APPROVE=true ./scripts/run-aws.sh
```

### Serviços AWS

| Serviço | Uso |
|---------|-----|
| EKS | Orquestração de containers (Kubernetes) |
| ECR | Repositório de imagens Docker |
| DocumentDB | Banco MongoDB compatível |
| SQS | Filas de mensagens |
| ALB | Load balancer |
| CloudWatch | Logs, métricas e alarmes |
| X-Ray | Tracing distribuído |
| IAM | Permissões |
| Secrets Manager | Gerenciamento de credenciais (MongoDB URI, JWT, SQS, API) |

---

## Observabilidade

### CloudWatch Metrics (AWS)

A aplicação exporta as seguintes métricas para CloudWatch:

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `TransactionsProcessed` | Counter | Total de transações processadas |
| `TransactionSuccessRate` | Gauge | Taxa de sucesso das transações (%) |
| `AuthorizationLatency` | Timer | Latência de autorização (segundos) |
| `CircuitBreakerState` | Gauge | Estado do Circuit Breaker (0=CLOSED, 1=OPEN, 2=HALF_OPEN) |
| `CircuitBreakerFailureRate` | Gauge | Taxa de falha do Circuit Breaker (%) |
| `SQSMessagesConsumed` | Counter | Mensagens SQS consumidas |

### X-Ray Distributed Tracing

A aplicação gera spans de execução para rastreamento distribuído:

| Span | Descrição |
|------|-----------|
| `transaction.authorize` | Autorização de transação |
| `mongodb.query` | Consultas ao banco |
| `sqs.consume` | Consumo de mensagens SQS |
| `http.server.request` | Requisições HTTP recebidas |
| `http.client.request` | Chamadas HTTP externas |

### AWS X-Ray Distributed Tracing

A aplicação utiliza o **AWS X-Ray SDK** para tracing distribuído, funcionando tanto com LocalStack (local) quanto com AWS real.

**Como funciona:**
- O `AWSXRayServletFilter` intercepta todas as requisições HTTP em `/api/*` e cria traces automaticamente
- O `XRayConfig` configura o recorder com `NoSamplingStrategy` (100% das requisições tracejadas)
- Os traces são enviados para o endpoint configurado via `AWS_ENDPOINT_URL`

**LocalStack:** X-Ray é ativado via `SERVICES=xray` e `XRAY_ENABLED=1` no docker-compose
**AWS:** X-Ray é ativado via IAM policy `AWSXRayDaemonWriteAccess` no EKS node group

### Logs no S3

Os logs da aplicação são enviados para um bucket S3, que pode ser simulado localmente pelo LocalStack:

- **LocalStack**: `s3://transaction-api-logs/{environment}/{service}/{date}/{service}-{timestamp}.log`
- **AWS**: Bucket S3 real configurado via Terraform

O appender `S3LogAppender` faz buffer dos logs e faz upload em lote a cada 50 eventos, minimizando chamadas à API S3.

Configuração via variáveis de ambiente:
- `S3_LOG_BUCKET` - Nome do bucket (default: `transaction-api-logs`)
- `SERVICE_NAME` - Nome do serviço (default: `transaction-api`)
- `ENVIRONMENT` - Ambiente (default: `local`)
- `AWS_ENDPOINT_URL` - Endpoint S3 (LocalStack ou AWS)

### Dashboard do CloudWatch

Os dashboards são carregados automaticamente via Terraform:
- **Transaction API - Overview** - Métricas principais
- **Transaction API - Circuit Breaker** - Estado do circuit breaker
- **Transaction API - SQS** - Métricas de filas
- **Transaction API - Infrastructure** - Métricas de infraestrutura

---

## Secrets Manager — Como as Credenciais São Carregadas

O `SecretsManagerLoader` é um `EnvironmentPostProcessor` do Spring Boot que carrega secrets do AWS Secrets Manager no startup da aplicação.

### Fluxo de Carregamento

1. Verifica se `app.secrets.aws.enabled=true` (ou `AWS_SECRETS_ENABLED=true`)
2. Conecta ao Secrets Manager (via endpoint configurado em `aws.endpoint-url`)
3. Para cada secret, verifica se a propriedade já existe como variável de ambiente (`System.getenv`)
4. Se a variável de ambiente **não** existir, a propriedade é carregada do secret e injetada via `System.setProperty` + `MapPropertySource`

### Secrets Carregados

| Secret | Propriedades | Propósito |
|--------|-------------|-----------|
| `transaction-api/mongodb` | `spring.data.mongodb.uri` | URI de conexão com MongoDB/DocumentDB |
| `transaction-api/jwt` | `app.security.jwt.secret`, `app.security.jwt.issuer` | Chave JWT |
| `transaction-api/credentials` | `app.security.client.id`, `app.security.client.secret` | Credenciais da API |
| `transaction-api/sqs` | `aws.endpoint-url`, `aws.region` | Configuração SQS |

### Prioridade de Resolução

```
Variável de Ambiente (System.getenv) → Secrets Manager → Valor default do application.yml
```

---

## CI/CD

| Workflow | Trigger | Ação |
|----------|---------|------|
| `ci.yml` | Push/PR | Build + Test + Coverage + Docker |
| `cd-staging.yml` | Push to develop | Deploy staging |
| `cd-production.yml` | Manual | Deploy production |

---

## Decisões Arquiteturais (ADR)

| ADR | Decisão | Motivação |
|-----|---------|-----------|
| 001 | Kotlin + Spring Boot | Conciseness, null safety, coroutine support |
| 002 | DocumentDB (MongoDB compatible) | Flexible model, AWS compatible |
| 003 | DDD + Multi-Module | Separation of concerns, testability |
| 004 | Resilience4j | Industry standard, lightweight |
| 005 | TestContainers | Reliable integration tests |
| 006 | JaCoCo | Integrated coverage enforcement |
| 007 | EKS (Kubernetes) | Container orchestration |
| 008 | AWS Secrets Manager | Gerenciamento seguro de credenciais |
| 009 | CloudWatch Metrics | Monitoramento nativo AWS |
| 010 | X-Ray | Tracing distribuído |
| 011 | **MongoDB para simular DocumentDB** | LocalStack não possui DocumentDB nativo; usa MongoDB em container separado |
| 012 | **URI do MongoDB via env var ou Secrets Manager** | `application.yml` não define `spring.data.mongodb.uri`; a resolução é feita por variável de ambiente ou Secrets Manager no startup |

---

## License

MIT