# 📋 Plano de Implementação – Desafio Técnico

## Visão Geral

Implementação completa de uma **API de Autorização de Transações Financeiras** em **Kotlin com Spring Boot**, seguindo arquitetura **Domain Driven Design (DDD)**, com padrões de resiliência (Circuit Breaker, DLQ), infraestrutura Docker local e Terraform para deploy na AWS (ECS/EKS).

---

## 📊 Arquitetura Geral do Sistema

```mermaid
graph TB
    subgraph "Amazon ECS / EKS"
        subgraph "VPC"
            subgraph "Private Subnet"
                subgraph "ECS Cluster / EKS Namespace"
                    API1["API Instance 1<br/>Spring Boot + Kotlin"]
                    API2["API Instance 2<br/>Spring Boot + Kotlin"]
                    API3["API Instance N<br/>Spring Boot + Kotlin"]
                end
            end
            subgraph "Data Subnet"
                MongoDB[("DocumentDB<br/>(MongoDB Compatible)")]
            end
        end
        ALB["Application<br/>Load Balancer"]
        APIGW["API Gateway"]
    end

    subgraph "AWS Services"
        SQS["SQS Queue<br/>conta-bancaria-criada"]
        DLQ["SQS Dead Letter Queue<br/>conta-bancaria-criada-dlq"]
        CW["CloudWatch<br/>Metrics & Logs"]
    end

    subgraph "Config & Discovery"
        Consul["🗄️ Consul<br/>(Config + Discovery)"]
        Vault["🔐 Vault<br/>(Secrets)"]
    end

    subgraph "Observability"
        Prometheus["Prometheus<br/>(Metrics)"]
        Grafana["Grafana<br/>(Dashboards)"]
        Jaeger["Jaeger<br/>(Tracing)"]
        Loki["Loki<br/>(Logs)"]
    end

    subgraph "External Systems"
        Client["👤 Cliente"]
        Abertura["🏢 Abertura de<br/>Contas"]
    end

    Client -->|"POST /api/v1/transactions/{transactionId}"| APIGW
    APIGW --> ALB
    ALB --> API1 & API2 & API3
    API1 & API2 & API3 --> MongoDB
    Abertura --> SQS
    SQS --> API1 & API2 & API3
    SQS -.->|"maxReceiveCount=5"| DLQ
    API1 & API2 & API3 --> CW
    Consul -->|"config + discovery"| API1 & API2 & API3
    Vault -->|"secrets"| API1 & API2 & API3
    API1 & API2 & API3 --> Prometheus
    API1 & API2 & API3 --> Jaeger
    API1 & API2 & API3 --> Loki
    Prometheus --> Grafana
```

---

## 🏗️ Estrutura do Projeto (Multi-Módulo Maven + DDD)

```
desafiodecdigoita/
├── pom.xml                          # Parent POM (multi-module)
├── docker-compose.yml               # Local environment (extended)
├── Dockerfile                       # Multi-stage Docker build
├── README.md                        # Documentação completa
├── .gitignore
│
├── transaction-domain/              # Módulo Domain (Core)
│   ├── pom.xml
│   └── src/
│       └── main/kotlin/com/itau/transaction/domain/
│           ├── model/
│           │   ├── Account.kt                    # Aggregate Root
│           │   ├── Transaction.kt                # Value Object / Entity
│           │   ├── Money.kt                      # Value Object (amount + currency)
│           │   ├── TransactionType.kt            # Enum: CREDIT, DEBIT
│           │   ├── TransactionStatus.kt          # Enum: SUCCEEDED, FAILED
│           │   └── AccountStatus.kt              # Enum: ENABLED, DISABLED
│           ├── event/
│           │   ├── AccountCreatedEvent.kt        # Domain Event
│           │   └── TransactionAuthorizedEvent.kt # Domain Event
│           ├── exception/
│           │   ├── AccountNotFoundException.kt
│           │   ├── InsufficientBalanceException.kt
│           │   └── AccountDisabledException.kt
│           ├── port/
│           │   ├── AccountRepositoryPort.kt      # Output port (porta de saída)
│           │   ├── TransactionRepositoryPort.kt  # Output port
│           │   └── EventPublisherPort.kt         # Output port
│           └── service/
│               ├── TransactionAuthorizationService.kt  # Domain Service (use case)
│               └── AccountRegistrationService.kt       # Domain Service (use case)
│
├── transaction-application/        # Módulo Application (Use Cases / Orchestration)
│   ├── pom.xml
│   └── src/
│       ├── main/kotlin/com/itau/transaction/application/
│       │   ├── dto/
│       │   │   ├── request/
│       │   │   │   └── TransactionRequest.kt
│       │   │   └── response/
│       │   │       ├── TransactionResponse.kt
│       │   │       └── AccountResponse.kt
│       │   ├── mapper/
│       │   │   ├── TransactionMapper.kt
│       │   │   └── AccountMapper.kt
│       │   ├── service/
│       │   │   ├── AuthorizeTransactionUseCase.kt  # Application Service
│       │   │   └── RegisterAccountUseCase.kt        # Application Service
│       │   └── consumer/
│       │       └── AccountCreatedConsumer.kt         # SQS Consumer
│       └── test/kotlin/com/itau/transaction/application/
│           ├── service/
│           │   ├── AuthorizeTransactionUseCaseTest.kt
│           │   └── RegisterAccountUseCaseTest.kt
│           └── consumer/
│               └── AccountCreatedConsumerTest.kt
│
├── transaction-infrastructure/     # Módulo Infrastructure (Adapters)
│   ├── pom.xml
│   └── src/
│       ├── main/kotlin/com/itau/transaction/infrastructure/
│       │   ├── config/
│       │   │   ├── AwsSqsConfig.kt               # SQS configuration
│       │   │   ├── MongoConfig.kt                 # MongoDB configuration
│       │   │   ├── CircuitBreakerConfig.kt        # Resilience4j Circuit Breaker
│       │   │   └── JacksonConfig.kt               # JSON serialization
│       │   ├── persistence/
│       │   │   ├── entity/
│       │   │   │   ├── AccountDocument.kt         # MongoDB document
│       │   │   │   └── TransactionDocument.kt     # MongoDB document
│       │   │   ├── repository/
│       │   │   │   ├── AccountMongoRepository.kt  # Spring Data MongoDB
│       │   │   │   └── TransactionMongoRepository.kt
│       │   │   ├── mapper/
│       │   │   │   ├── AccountDocumentMapper.kt
│       │   │   │   └── TransactionDocumentMapper.kt
│       │   │   └── adapter/
│       │   │       ├── AccountRepositoryAdapter.kt   # implements AccountRepositoryPort
│       │   │       └── TransactionRepositoryAdapter.kt # implements TransactionRepositoryPort
│       │   ├── messaging/
│       │   │   ├── producer/
│       │   │   │   └── SqsEventPublisher.kt       # implements EventPublisherPort
│       │   │   └── consumer/
│       │   │       └── SqsAccountCreatedListener.kt # SQS listener
│       │   └── resilience/
│       │       └── CircuitBreakerAspect.kt         # AOP Circuit Breaker
│       └── test/kotlin/com/itau/transaction/infrastructure/
│           └── persistence/
│               ├── AccountRepositoryAdapterTest.kt
│               └── TransactionRepositoryAdapterTest.kt
│
├── transaction-api/                # Módulo API (Interface Adapters / Controllers)
│   ├── pom.xml
│   └── src/
│       ├── main/kotlin/com/itau/transaction/api/
│       │   ├── TransactionApplication.kt          # Spring Boot Main Class
│       │   ├── controller/
│       │   │   └── TransactionController.kt       # REST Controller
│       │   ├── exception/
│       │   │   ├── GlobalExceptionHandler.kt      # @ControllerAdvice
│       │   │   ├── ErrorResponse.kt               # Standard error DTO
│       │   │   └── AccountNotFoundException.kt
│       │   └── config/
│       │       └── SwaggerConfig.kt               # OpenAPI/Swagger config
│       ├── main/resources/
│       │   ├── application.yml                    # Main config
│       │   ├── application-docker.yml             # Docker profile
│       │   └── application-test.yml               # Test profile
│       └── test/kotlin/com/itau/transaction/api/
│           ├── controller/
│           │   └── TransactionControllerTest.kt   # Unit test
│           ├── integration/
│           │   └── TransactionApiIntegrationTest.kt  # Integration test
│           └── resources/
│               └── testcontainers/                # Testcontainers config
│
├── terraform/                      # Infraestrutura como Código
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── ecs.tf
│   ├── ecr.tf
│   ├── documentdb.tf
│   ├── sqs.tf
│   ├── alb.tf
│   ├── iam.tf
│   ├── cloudwatch.tf
│   └── environments/
│       ├── dev.tfvars
│       └── staging.tfvars
│
├── .github/                        # CI/CD GitHub Actions
│   └── workflows/
│       ├── ci.yml                  # Build + Test + Coverage
│       ├── cd-staging.yml          # Deploy to staging
│       └── cd-production.yml       # Deploy to production
│
├── postman/                        # Collections Postman
│   └── TransactionAPI.postman_collection.json
│
├── scripts/                        # Scripts de Apoio
│   ├── run-local.sh                # Roda app via docker-compose
│   ├── build.sh                    # Build completo (mvn clean package)
│   ├── test.sh                     # Roda todos os testes
│   ├── test-unit.sh                # Apenas testes unitários
│   ├── test-integration.sh         # Apenas testes de integração
│   ├── coverage.sh                 # Gera relatório de cobertura
│   ├── seed-accounts.sh            # Popula SQS com contas de teste
│   └── check-queue.sh              # Verifica mensagens na fila
│
└── docs/                           # Documentação
    ├── architecture.md             # ADRs e decisões
    ├── api-spec.yaml               # OpenAPI spec
    └── diagrams/
        ├── sequence-authorization.mmd
        ├── sequence-account-registration.mmd
        └── architecture-overview.mmd
```

---

## 🗄️ Modelo de Dados (DocumentDB / MongoDB)

### Collection: `accounts`

```json
{
  "_id": "ObjectId",
  "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
  "owner": "315e3cfe-f4af-4cd2-b298-a449e614349a",
  "balance": {
    "amount": 0.00,
    "currency": "BRL"
  },
  "status": "ENABLED",
  "created_at": "2025-07-08T10:00:00-03:00",
  "updated_at": "2025-07-08T10:00:00-03:00",
  "version": 0
}
```

### Collection: `transactions`

```json
{
  "_id": "ObjectId",
  "id": "8e8ae808-b154-48b5-9f3e-553935cc4543",
  "account_id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
  "type": "CREDIT",
  "amount": {
    "value": 97.07,
    "currency": "BRL"
  },
  "status": "SUCCEEDED",
  "timestamp": "2025-07-08T15:57:55-03:00",
  "created_at": "2025-07-08T15:57:55-03:00"
}
```

---

## 🔐 Autenticação e Segurança (JWT + Cache)

### Visão Geral

A aplicação implementa autenticação via **JWT (JSON Web Token)** com tokens de **24 horas** de validade. A validação dos tokens é otimizada com **Caffeine Cache** em memória para garantir performance na verificação de cada request.

### Fluxo de Autenticação

```mermaid
sequenceDiagram
    participant Client as 👤 Cliente
    participant Auth as 🔑 AuthController
    participant Cache as 💾 Caffeine Cache
    participant JWT as 🎫 JWT Service
    participant API as 🔧 TransactionController
    participant SecFilter as 🛡️ Security Filter

    Note over Client,SecFilter: === Geração de Token ===
    Client->>Auth: POST /api/v1/auth/token<br/>{clientId, clientSecret}
    Auth->>Auth: Validate credentials<br/>(in-memory or DB)
    Auth->>JWT: Generate token<br/>(24h expiration)
    JWT-->>Auth: JWT Token
    Auth-->>Client: 200 OK<br/>{token, expiresIn: 86400}

    Note over Client,SecFilter: === Requisição Autenticada ===
    Client->>API: POST /api/v1/transactions/{id}<br/>Header: Authorization: Bearer {token}
    API->>SecFilter: Intercept request
    SecFilter->>Cache: Check token in cache
    alt Token in Cache (HIT)
        Cache-->>SecFilter: Token valid (cached)
    else Token not in Cache (MISS)
        SecFilter->>JWT: Validate token
        JWT-->>SecFilter: Token valid
        SecFilter->>Cache: Store token in cache (TTL=24h)
    end
    SecFilter->>API: Request authenticated
    API-->>Client: 200 OK
```

### Endpoints de Autenticação

#### POST `/api/v1/auth/token`

**Request Body:**
```json
{
  "client_id": "transaction-api-client",
  "client_secret": "super-secret-key-123"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "expires_at": "2025-07-09T15:57:55-03:00"
}
```

**Response (401 Unauthorized):**
```json
{
  "error": "UNAUTHORIZED",
  "message": "Invalid client credentials",
  "timestamp": "2025-07-08T15:57:55-03:00"
}
```

### Configuração JWT

```yaml
app:
  security:
    jwt:
      secret: ${JWT_SECRET:MyDefaultSecretKeyForDevelopmentOnly2024!}
      expiration: 86400          # 24 horas em segundos
      issuer: transaction-api
      header: Authorization
      prefix: "Bearer "
    clients:
      - id: transaction-api-client
        secret: $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy  # bcrypt
        roles: [ADMIN, API]
      - id: transaction-api-readonly
        secret: $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy
        roles: [API]
```

### Cache de Tokens (Caffeine)

```yaml
spring:
  cache:
    type: caffeine
    caffeine:
      spec: maximumSize=1000,expireAfterWrite=24h
    cache-names:
      - jwt-tokens
```

**Configuração Caffeine:**

| Parâmetro | Valor | Descrição |
|-----------|-------|-----------|
| `maximumSize` | 1000 | Máximo de tokens em cache |
| `expireAfterWrite` | 24h | TTL igual à expiração do token |
| `recordStats` | true | Habilita métricas do cache |

### Componentes Implementados

```
transaction-infrastructure/src/main/kotlin/.../infrastructure/
├── security/
│   ├── JwtTokenProvider.kt          # Geração e validação de JWT
│   ├── JwtAuthenticationFilter.kt   # OncePerRequestFilter
│   ├── SecurityConfig.kt            # HttpSecurity configuration
│   └── ClientCredentials.kt         # Model de credenciais

transaction-api/src/main/kotlin/.../api/
├── controller/
│   └── AuthController.kt            # POST /api/v1/auth/token
```

### JwtAuthenticationFilter (Conceitual)

```kotlin
@Component
class JwtAuthenticationFilter(
    private val jwtTokenProvider: JwtTokenProvider,
    private val cacheManager: CacheManager
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val token = extractToken(request)
        
        if (token != null) {
            val cache = cacheManager.getCache("jwt-tokens")
            val cachedSubject = cache?.get(token, String::class.java)
            
            val subject = cachedSubject ?: run {
                val validated = jwtTokenProvider.validateAndGetSubject(token)
                cache?.put(token, validated)
                validated
            }
            
            val authentication = UsernamePasswordAuthenticationToken(
                subject, null, emptyList()
            )
            SecurityContextHolder.getContext().authentication = authentication
        }
        
        filterChain.doFilter(request, response)
    }
}
```

### Fluxo de Validação com Cache

```mermaid
flowchart TD
    Start["📥 Request arrives"] --> Extract["🔑 Extract token<br/>from Authorization header"]
    Extract --> HasToken{"Token<br/>present?"}
    HasToken -->|"No"| Next["⛓️ Continue filter chain<br/>(unauthenticated)"]
    HasToken -->|"Yes"| CacheCheck{"💾 Cache<br/>HIT?"}
    
    CacheCheck -->|"HIT"| Auth["✅ Set authentication<br/>(from cache)"]
    CacheCheck -->|"MISS"| Validate["🔍 Validate JWT<br/>(signature + expiry)"]
    
    Validate --> Valid{"Token<br/>valid?"}
    Valid -->|"No"| Reject["❌ 401 Unauthorized"]
    Valid -->|"Yes"| Store["💾 Store in Caffeine<br/>(TTL=24h)"]
    Store --> Auth
    
    Auth --> Next
    Next --> Controller["🔧 Controller"]
    
    style Start fill:#4CAF50,stroke:#2E7D32,color:#fff
    style CacheCheck fill:#2196F3,stroke:#1565C0,color:#fff
    style Auth fill:#4CAF50,stroke:#2E7D32,color:#fff
    style Reject fill:#f44336,stroke:#B71C1C,color:#fff
    style Next fill:#607D8B,stroke:#37474F,color:#fff
```

### Segurança Adicional

| Medida | Descrição |
|--------|-----------|
| **BCrypt** | Senhas dos clients armazenadas com hash bcrypt |
| **HTTPS** | Em produção, TLS termination no ALB |
| **CORS** | Configurado para aceitar apenas origens específicas |
| **Rate Limiting** | Pode ser adicionado via bucket4j no futuro |
| **Token Expiry** | 24h, sem refresh token (simplificação para o teste) |
| **Cache TTL** | Sincronizado com expiração do token |

### Dependências Maven (Segurança)

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.6</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
```

---

## 🔌 API REST – Endpoints

> ⚠️ Todos os endpoints (exceto `/api/v1/auth/token`) requerem header `Authorization: Bearer {JWT_TOKEN}`

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
    "amount": {
      "value": 97.07,
      "currency": "BRL"
    },
    "status": "SUCCEEDED",
    "timestamp": "2025-07-08T15:57:55-03:00"
  },
  "account": {
    "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
    "balance": {
      "amount": 183.12,
      "currency": "BRL"
    }
  }
}
```

**Response (422 Unprocessable Entity – Account Not Found):**
```json
{
  "error": "ACCOUNT_NOT_FOUND",
  "message": "Account with id 5b19c8b6-0cc4-4c72-a989-0c2ee15fa975 was not found",
  "timestamp": "2025-07-08T15:57:55-03:00"
}
```

**Response (422 Unprocessable Entity – Insufficient Balance):**
```json
{
  "error": "INSUFFICIENT_BALANCE",
  "message": "Account has insufficient balance for debit transaction. Current: 50.00, Requested: 100.00",
  "timestamp": "2025-07-08T15:57:55-03:00"
}
```

---

## 🔄 Fluxo de Autorização de Transação

```mermaid
sequenceDiagram
    participant Client as 👤 Cliente
    participant API as 🔧 API (TransactionController)
    participant UC as 📋 UseCase (AuthorizeTransaction)
    participant DS as ⚙️ DomainService
    participant CB as 🛡️ CircuitBreaker
    participant Repo as 🗄️ MongoDB
    participant SQS as 📨 SQS (conta-bancaria-criada)
    participant DLQ as ❌ Dead Letter Queue

    Client->>API: POST /api/v1/transactions/{id}
    API->>CB: Execute with Circuit Breaker
    CB->>UC: authorize(transactionId, request)
    UC->>Repo: findByAccountId(accountId)
    Repo-->>UC: Account (or null)
    
    alt Account Not Found
        UC-->>API: AccountNotFoundException
        API-->>Client: 422 ACCOUNT_NOT_FOUND
    else Account Found
        UC->>DS: authorize(account, transaction)
        DS->>DS: Validate operation type
        alt CREDIT
            DS->>DS: newBalance = current + amount
            DS->>Repo: save(newBalance)
            DS-->>UC: Transaction(SUCCEEDED)
        else DEBIT
            DS->>DS: newBalance = current - amount
            alt newBalance < 0
                DS-->>UC: Transaction(FAILED)
            else newBalance >= 0
                DS->>Repo: save(newBalance)
                DS-->>UC: Transaction(SUCCEEDED)
            end
        end
        UC-->>API: TransactionResponse
        API-->>Client: 200 OK
    end
```

---

## 🔄 Fluxo de Abertura de Conta (SQS Consumer)

```mermaid
sequenceDiagram
    participant Abertura as 🏢 Abertura de Contas
    participant SQS as 📨 SQS Queue
    participant Consumer as 🎧 SQS Consumer
    participant CB as 🛡️ CircuitBreaker
    participant UC as 📋 UseCase (RegisterAccount)
    participant Repo as 🗄️ MongoDB
    participant DLQ as ❌ Dead Letter Queue

    Abertura->>SQS: Publish AccountCreated message
    SQS->>Consumer: Poll message
    Consumer->>CB: Execute with Circuit Breaker
    CB->>UC: register(accountMessage)
    UC->>Repo: findByAccountId(id)
    
    alt Account Already Exists
        UC-->>Consumer: Idempotent skip
        Consumer->>SQS: Delete message (ack)
    else Account Not Found
        UC->>Repo: save(newAccount with balance=0)
        UC-->>Consumer: Account registered
        Consumer->>SQS: Delete message (ack)
    end
    
    alt Exception Thrown
        Consumer->>SQS: Return message (NACK)
        Note over SQS: After maxReceiveCount=5
        SQS->>DLQ: Move to Dead Letter Queue
    end
```

---

## 🛡️ Padrões de Resiliência

### Circuit Breaker (Resilience4j)

```mermaid
stateDiagram-v2
    [*] --> Closed
    Closed --> Open: failureRate >= 50%<br/>(slidingWindowSize=10)
    Open --> HalfOpen: waitDurationInOpenState=30s
    HalfOpen --> Closed: successRate >= 50%<br/>(permittedNumberOfCallsInHalfOpenState=3)
    HalfOpen --> Open: failureRate >= 50%
```

**Configuração:**
```yaml
resilience4j:
  circuitbreaker:
    instances:
      mongoDbCircuitBreaker:
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
        registerHealthIndicator: true
      sqsCircuitBreaker:
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
```

### Dead Letter Queue (DLQ)

```yaml
# SQS Queue Configuration
Queue: conta-bancaria-criada
  - Type: Standard
  - VisibilityTimeout: 30s
  - MessageRetentionPeriod: 4 days

Dead Letter Queue: conta-bancaria-criada-dlq
  - Type: Standard
  - MessageRetentionPeriod: 14 days
  - RedrivePolicy:
      maxReceiveCount: 5
      deadLetterTargetArn: arn:aws:sqs:sa-east-1:000000000000:conta-bancaria-criada-dlq
```

### Retry com Backoff e Jitter

```yaml
resilience4j:
  retry:
    instances:
      mongoDbRetry:
        maxAttempts: 3
        waitDuration: 500ms
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2
        retryExceptions:
          - org.springframework.dao.DataAccessResourceFailureException
          - com.mongodb.MongoException
      dlqRetry:
        maxAttempts: 3
        waitDuration: 1000ms
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 3
        retryExceptions:
          - org.springframework.dao.DataAccessResourceFailureException
          - com.mongodb.MongoException
          - software.amazon.awssdk.core.exception.SdkException
```

---

## 🔁 Reprocessamento da Dead Letter Queue (DLQ)

### Visão Geral

A DLQ não fica "solta". Implementamos um **DLQ Reprocessor Scheduler** que periodicamente consome mensagens da DLQ e tenta reprocessá-las, aplicando **Circuit Breaker** + **Retry com backoff** para evitar sobrecarga do sistema em falha.

### Fluxo de Reprocessamento

```mermaid
sequenceDiagram
    participant Scheduler as ⏰ DLQ Reprocessor<br/>(Scheduled Task)
    participant CB as 🛡️ CircuitBreaker
    participant DLQ as ❌ Dead Letter Queue<br/>(conta-bancaria-criada-dlq)
    participant UC as 📋 RegisterAccountUseCase
    participant Repo as 🗄️ MongoDB
    participant MainQ as 📨 Fila Principal<br/>(conta-bancaria-criada)

    loop A cada 5 minutos (configurável)
        Scheduler->>DLQ: receiveMessage(maxBatch=10)
        DLQ-->>Scheduler: Batch de mensagens
        
        alt Mensagens disponíveis
            loop Para cada mensagem
                Scheduler->>CB: executeWithCircuitBreaker
                CB->>UC: register(accountMessage)
                UC->>Repo: findById(id)
                
                alt Conta já existe
                    UC-->>CB: Idempotente (ok)
                    CB-->>Scheduler: Sucesso
                    Scheduler->>DLQ: deleteMessage (ack)
                else Conta não existe
                    UC->>Repo: save(newAccount)
                    UC-->>CB: Registrada
                    CB-->>Scheduler: Sucesso
                    Scheduler->>DLQ: deleteMessage (ack)
                end
            end
        else Nenhuma mensagem
            Note over Scheduler: Aguarda próximo ciclo
        end
    end

    Note over Scheduler,DLQ: Se CircuitBreaker OPEN → mensagens ficam na DLQ<br/>até o próximo ciclo quando CB vai para HALF-OPEN
```

### Componentes Implementados

```
transaction-infrastructure/src/main/kotlin/.../infrastructure/
├── scheduler/
│   └── DlqReprocessorScheduler.kt        # @Scheduled task que consome DLQ
├── messaging/
│   ├── consumer/
│   │   └── SqsAccountCreatedListener.kt  # Consumer da fila principal
│   └── reprocessor/
│       └── DlqMessageReprocessor.kt      # Lógica de reprocessamento com CircuitBreaker
```

### Regras de Negócio

| Regra | Descrição |
|-------|-----------|
| **Idempotência** | Se a conta já existe, a mensagem é descartada (rejeitada da DLQ) |
| **Circuit Breaker** | Se 50%+ das chamadas falham, CB abre e aguarda 30s antes de tentar novamente |
| **Batch Limit** | Consome no máximo 10 mensagens por ciclo para não sobrecarregar |
| **Ciclo Configurável** | Intervalo padrão: 5 minutos (`dlq.reprocessor.interval=PT5M`) |
| **Métricas** | Cada reprocessamento é logado com sucesso/falha para monitoramento |
| **Retenção** | DLQ retém mensagens por 14 dias; mensagens não reprocessadas são logadas |

### Configuração

```yaml
app:
  dlq:
    reprocessor:
      enabled: true
      interval: PT5M              # ISO-8601 duration (5 minutos)
      max-batch-size: 10          # Máximo de mensagens por ciclo
      queue-url: ${AWS_ENDPOINT_URL}/000000000000/conta-bancaria-criada-dlq
      visibility-timeout: 60      # Segundos

resilience4j:
  circuitbreaker:
    instances:
      dlqReprocessorCircuitBreaker:
        slidingWindowSize: 10
        minimumNumberOfCalls: 3
        failureRateThreshold: 50
        waitDurationInOpenState: 60s
        permittedNumberOfCallsInHalfOpenState: 2
        registerHealthIndicator: true
```

### Implementação Conceitual (DlqReprocessorScheduler.kt)

```kotlin
@Component
@Slf4j
class DlqReprocessorScheduler(
    private val sqsClient: SqsClient,
    private val reprocessor: DlqMessageReprocessor,
    private val dlqProperties: DlqProperties
) {

    @Scheduled(fixedDelayString = "\${app.dlq.reprocessor.interval:PT5M}")
    fun reprocessDlqMessages() {
        log.info("Starting DLQ reprocessing cycle")
        
        val messages = sqsClient.receiveMessage(
            ReceiveMessageRequest.builder()
                .queueUrl(dlqProperties.queueUrl)
                .maxNumberOfMessages(dlqProperties.maxBatchSize)
                .waitTimeSeconds(5)
                .build()
        ).messages()

        log.info("Received ${messages.size} messages from DLQ")

        messages.forEach { message ->
            try {
                reprocessor.reprocess(message)
                deleteMessage(message) // ACK
                log.info("Successfully reprocessed message ${message.messageId()}")
            } catch (e: Exception) {
                log.warn("Failed to reprocess message ${message.messageId()}: ${e.message}")
                // Mensagem volta para DLQ (NACK) com visibility timeout
            }
        }
    }
}
```

### Implementação Conceitual (DlqMessageReprocessor.kt)

```kotlin
@Component
@Slf4j
class DlqMessageReprocessor(
    private val registerAccountUseCase: RegisterAccountUseCase,
    private val circuitBreakerRegistry: CircuitBreakerRegistry
) {

    private val circuitBreaker: CircuitBreaker = 
        circuitBreakerRegistry.circuitBreaker("dlqReprocessorCircuitBreaker")

    fun reprocess(message: Message) {
        CircuitBreaker.decorateCallable(circuitBreaker) {
            val accountMessage = parseMessage(message.body())
            registerAccountUseCase.execute(accountMessage)
        }.call()
    }

    private fun parseMessage(body: String): AccountMessage {
        // Deserializa o JSON do SQS para AccountMessage
        return jacksonObjectMapper().readValue(body, AccountMessage::class.java)
    }
}
```

### Fluxo Decisão: Sucesso vs Falha na DLQ

```mermaid
flowchart TD
    Start["⏰ Scheduler dispara<br/>(a cada 5min)"] --> Receive["📨 receiveMessage<br/>(max 10 msgs)"]
    Receive --> HasMsgs{"Há mensagens?"}
    HasMsgs -->|"Não"| Wait["Aguarda próximo<br/>ciclo"]
    HasMsgs -->|"Sim"| Loop["Para cada mensagem"]
    Loop --> CB{"🛡️ Circuit<br/>Breaker?"}
    
    CB -->|"CLOSED<br/>(normal)"| Process["📋 registerAccount<br/>(idempotente)"]
    CB -->|"OPEN<br/>(muitas falhas)"| Skip["⏭️ Pular ciclo<br/>(aguardar HALF-OPEN)"]
    
    Process --> Exists{"Conta<br/>existe?"}
    Exists -->|"Sim"| Delete["🗑️ Deletar msg<br/>(idempotente OK)"]
    Exists -->|"Não"| Save["💾 Salvar conta<br/>balance=0"]
    Save --> Delete
    
    Delete --> MoreMsgs{"Mais msgs?"}
    MoreMsgs -->|"Sim"| Loop
    MoreMsgs -->|"Não"| End["✅ Ciclo finalizado"]
    Skip --> End
    Wait --> End

    style Start fill:#4CAF50,stroke:#2E7D32,color:#fff
    style CB fill:#2196F3,stroke:#1565C0,color:#fff
    style Delete fill:#4CAF50,stroke:#2E7D32,color:#fff
    style Skip fill:#FF9800,stroke:#E65100,color:#fff
    style Save fill:#607D8B,stroke:#37474F,color:#fff
```

### Por que isso importa

- **Saques** não podem falhar → processados imediatamente via fila principal com retry
- **Depósitos** podem falhar por instabilidade transitória → DLQ + reprocessamento garante que eventualmente serão processados
- **Circuit Breaker** na DLQ evita cascade failure: se o MongoDB está fora, não fica tentando infinitamente
- **Idempotência** garante que reprocessar uma mensagem que já foi criada não cause duplicidade

---

## 🧪 Estratégia de Testes (Pirâmide de Testes)

```mermaid
graph TB
    subgraph "🔺 Pirâmide de Testes"
        E2E["🔴 Testes E2E<br/>(Manual - Postman)<br/>2-5%"]
        INT["🟡 Testes de Integração<br/>(TestContainers)<br/>15-20%"]
        UNIT["🟢 Testes Unitários<br/>(JUnit 5 + Mockito)<br/>75-80%"]
    end

    UNIT --> INT --> E2E
```

### Stack de Testes

| Camada | Ferramenta | Descrição |
|--------|------------|-----------|
| **Unitários** | JUnit 5 + Mockito + AssertJ | Mocks com Mockito, assertions fluentes com AssertJ |
| **Integração** | TestContainers + JUnit 5 | Chamadas reais a MongoDB/SQS via containers Docker |
| **Cobertura** | JaCoCo | Enforce ≥ 80% de cobertura de linhas |
| **Manuais** | Postman Collection | Testes manuais com docker-compose rodando |

### Dependências de Teste (Maven)

```xml
<!-- Test Dependencies -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>mongodb</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
```

### Cobertura de Código: ≥ 80%

**Ferramenta:** JaCoCo via Maven plugin + relatório no build.

```xml
<!-- No parent pom.xml -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.12</version>
    <executions>
        <execution>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals><goal>report</goal></goals>
        </execution>
        <execution>
            <id>check</id>
            <goals><goal>check</goal></goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Testes a Implementar:

| Módulo | Tipo | Arquivo | Descrição |
|--------|------|---------|-----------|
| domain | Unit | `TransactionAuthorizationServiceTest.kt` | Testes do domínio de autorização |
| domain | Unit | `AccountRegistrationServiceTest.kt` | Testes do domínio de cadastro |
| application | Unit | `AuthorizeTransactionUseCaseTest.kt` | Testes do caso de uso |
| application | Unit | `RegisterAccountUseCaseTest.kt` | Testes do caso de uso |
| application | Unit | `AccountCreatedConsumerTest.kt` | Testes do consumer SQS |
| infrastructure | Unit | `AccountRepositoryAdapterTest.kt` | Testes do adapter MongoDB |
| infrastructure | Unit | `TransactionRepositoryAdapterTest.kt` | Testes do adapter MongoDB |
| infrastructure | Unit | `SqsEventPublisherTest.kt` | Testes do publisher SQS |
| api | Unit | `TransactionControllerTest.kt` | Testes do controller |
| api | Unit | `GlobalExceptionHandlerTest.kt` | Testes do handler de erros |
| api | Integration | `TransactionApiIntegrationTest.kt` | API completa com TestContainers |
| api | Integration | `AccountRegistrationIntegrationTest.kt` | Consumer SQS + MongoDB |

---

## 🐳 Docker

### Dockerfile (Multi-Stage Build)

```dockerfile
# Stage 1: Build
FROM maven:3.9.6-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY transaction-domain/pom.xml transaction-domain/
COPY transaction-application/pom.xml transaction-application/
COPY transaction-infrastructure/pom.xml transaction-infrastructure/
COPY transaction-api/pom.xml transaction-api/
RUN mvn dependency:go-offline -B
COPY . .
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/transaction-api/target/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### docker-compose.yml Estendido (Local)

```yaml
services:
  # --- Infraestrutura existente ---
  localstack:
    # (mantido conforme original)
  
  message-generator:
    # (mantido conforme original)

  # --- Config & Discovery ---
  consul:
    image: hashicorp/consul:1.19
    container_name: consul
    ports:
      - "127.0.0.1:8500:8500"   # UI
      - "127.0.0.1:8600:8600"   # DNS
    volumes:
      - ./data/consul:/consul/data
      - ./consul/config:/consul/config
    command: agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -config-dir=/consul/config
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8500/v1/status/leader"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Infraestrutura adicionada ---
  mongodb:
    image: mongo:7.0
    container_name: mongodb
    ports:
      - "127.0.0.1:27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: admin123
      MONGO_INITDB_DATABASE: transaction_db
    volumes:
      - ./data/mongodb:/data/db          # Volume no host (fora do container)
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Aplicação ---
  transaction-api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: transaction-api
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATA_MONGODB_URI: mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin
      AWS_ENDPOINT_URL: http://localstack:4566
      AWS_DEFAULT_REGION: sa-east-1
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
      CONSUL_HOST: consul
      CONSUL_PORT: 8500
    depends_on:
      mongodb:
        condition: service_healthy
      localstack:
        condition: service_healthy
      consul:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 60s

  # --- Observability ---
  prometheus:
    image: prom/prometheus:v2.53.0
    container_name: prometheus
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./data/prometheus:/prometheus     # Volume no host
      - ./observability/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 10s
      timeout: 5s
      retries: 5

  thanos-sidecar:
    image: quay.io/thanos/thanos:v0.35.0
    container_name: thanos-sidecar
    command:
      - sidecar
      - --tsdb.path=/prometheus
      - --prometheus.url=http://prometheus:9090
      - --objstore.config-file=/etc/thanos/bucket.yml
    volumes:
      - ./data/prometheus:/prometheus     # Volume no host
      - ./observability/thanos/bucket.yml:/etc/thanos/bucket.yml
    depends_on:
      - prometheus

  jaeger:
    image: jaegertracing/all-in-one:1.59
    container_name: jaeger
    ports:
      - "127.0.0.1:16686:16686"
      - "127.0.0.1:4317:4317"
      - "127.0.0.1:4318:4318"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:14269/"]
      interval: 10s
      timeout: 5s
      retries: 5

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "127.0.0.1:3100:3100"
    volumes:
      - ./data/loki:/loki               # Volume no host
      - ./observability/loki/loki.yml:/etc/loki/local-config.yaml
    command: -config.file=/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3100/ready"]
      interval: 10s
      timeout: 5s
      retries: 5

  grafana:
    image: grafana/grafana:11.1.0
    container_name: grafana
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    volumes:
      - ./data/grafana:/var/lib/grafana  # Volume no host
      - ./observability/grafana/provisioning:/etc/grafana/provisioning
      - ./observability/grafana/dashboards:/var/lib/grafana/dashboards
    depends_on:
      prometheus:
        condition: service_healthy
      jaeger:
        condition: service_healthy
      loki:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  vault:
    image: hashicorp/vault:1.16
    container_name: vault
    ports:
      - "127.0.0.1:8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=root-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    command: server -dev
    volumes:
      - ./data/vault:/vault/data         # Volume no host
    healthcheck:
      test: ["CMD", "vault", "status"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Estrutura de Volumes no Host

```
desafiodecdigoita/
├── data/                              # Dados persistentes (NÃO commitar)
│   ├── mongodb/                       # Dados do MongoDB
│   ├── prometheus/                    # Métricas do Prometheus
│   ├── loki/                          # Logs do Loki
│   ├── grafana/                       # Configurações do Grafana
│   ├── vault/                         # Dados do Vault
│   └── consul/                        # Dados do Consul
├── observability/                     # Configurações (commitar)
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── thanos/
│   │   └── bucket.yml
│   ├── loki/
│   │   └── loki.yml
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/
│       │   │   └── datasources.yml
│       │   └── dashboards/
│       │       └── dashboards.yml
│       └── dashboards/
│           ├── transaction-api.json
│           ├── dlq-monitoring.json
│           └── infrastructure.json
```

### Regras de Volumes

| Pasta | Conteúdo | Git |
|-------|----------|-----|
| `data/` | Dados persistentes (MongoDB, Prometheus, Loki, Grafana, Vault, Consul) | ❌ **NÃO commitar** |
| `observability/` | Configurações de infraestrutura (YAML, JSON) | ✅ **Commitar** |
| `data/` (inicialização) | Pasta criada vazia via `scripts/run-local.sh` | ✅ **Commitar .gitkeep** |

### Inicialização da Pasta data/

O script `run-local.sh` deve criar a pasta `data/` com subpastas vazias antes de subir os containers:

```bash
# Criar pastas de dados (volumes do host)
mkdir -p data/{mongodb,prometheus,loki,grafana,vault,consul}
```

### .gitignore para data/

```gitignore
# Docker volumes (persistent data - NOT to be committed)
data/
!data/.gitkeep
```

### Terraform - Infraestrutura AWS

Para a infraestrutura AWS via Terraform, utilizamos os serviços nativos da AWS:

### Arquivo: `consul.tf`

```terraform
# Consul Cluster (ECS Fargate)
resource "aws_ecs_task_definition" "consul_server" {
  family                   = "consul-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "consul-server"
    image     = "hashicorp/consul:1.19"
    essential = true
    portMappings = [{
      containerPort = 8500
      hostPort      = 8500
      protocol      = "tcp"
    }]
    command = ["agent", "-server", "-bootstrap-expect=1", "-ui", "-client=0.0.0.0"]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.consul.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "consul"
      }
    }
  }])

  tags = {
    Name        = "consul-server"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "consul_server" {
  name            = "consul-server"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consul_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.consul.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.consul.arn
    container_name   = "consul-server"
    container_port   = 8500
  }

  depends_on = [aws_lb_listener.consul]
}

# Security Group para Consul
resource "aws_security_group" "consul" {
  name_prefix = "consul-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB para Consul UI
resource "aws_lb" "consul" {
  name               = "consul-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.consul.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "consul" {
  name     = "consul-tg"
  port     = 8500
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/v1/status/leader"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }
}

resource "aws_lb_listener" "consul" {
  load_balancer_arn = aws_lb.consul.arn
  port              = 8500
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul.arn
  }
}

# CloudWatch Log Group para Consul
resource "aws_cloudwatch_log_group" "consul" {
  name              = "/ecs/consul-server"
  retention_in_days = 14
}

# Output do Consul
output "consul_ui_url" {
  value = "http://${aws_lb.consul.dns_name}:8500"
}
```

| Serviço | Recurso Terraform | Descrição |
|---------|-------------------|-----------|
| **VPC** | `aws_vpc`, `aws_subnet`, `aws_nat_gateway` | Rede isolada |
| **ECS** | `aws_ecs_cluster`, `aws_ecs_service`, `aws_ecs_task_definition` | Orquestração de containers |
| **ECR** | `aws_ecr_repository` | Repositório de imagens Docker |
| **DocumentDB** | `aws_docdb_cluster`, `aws_docdb_instance` | Banco MongoDB compatível |
| **SQS** | `aws_sqs_queue` | Filas de mensagens |
| **ALB** | `aws_lb`, `aws_lb_target_group`, `aws_lb_listener` | Load balancer |
| **IAM** | `aws_iam_role`, `aws_iam_policy` | Permissões |
| **CloudWatch** | `aws_cloudwatch_log_group`, `aws_cloudwatch_metric_alarm` | Logs e alertas |
| **Secrets Manager** | `aws_secretsmanager_secret` | Armazenamento de senhas |
| **Prometheus** | `aws_prometheus_workspace` | Métricas gerenciadas |
| **Grafana** | `aws_grafana_workspace` | Dashboards gerenciados |
| **S3** | `aws_s3_bucket` | Armazenamento de objetos (Thanos) |
| **X-Ray** | `aws_xray_group` | Distributed tracing |

### Diagrama de Deploy AWS (Terraform)

```mermaid
graph TB
    subgraph "AWS Cloud - sa-east-1"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets"
                ALB["ALB"]
                NAT["NAT Gateway"]
            end
            subgraph "Private Subnets - Application"
                ECS["ECS Cluster"]
                Task1["Task: transaction-api<br/>(2 vCPU, 4GB)"]
                Task2["Task: transaction-api<br/>(2 vCPU, 4GB)"]
                ConsulSidecar["Consul Sidecar<br/>(config + discovery)"]
            end
            subgraph "Private Subnets - Data"
                DocDB[("DocumentDB<br/>db.r6g.large")]
            end
        end
        
        ECR["ECR<br/>transaction-api"]
        SQS["SQS<br/>conta-bancaria-criada"]
        DLQ["SQS DLQ<br/>conta-bancaria-criada-dlq"]
        CW["CloudWatch<br/>Logs & Alarms"]
        IAM["IAM Roles"]
        AMP["Amazon Managed<br/>Prometheus"]
        AMG["Amazon Managed<br/>Grafana"]
        XRay["AWS X-Ray"]
        S3["S3<br/>(Thanos metrics)"]
        SM["Secrets Manager"]
        Consul["Consul<br/>(Config + Discovery)"]
    end
    
    ECR --> ECS
    ECS --> Task1 & Task2
    Task1 & Task2 --> DocDB
    SQS --> Task1 & Task2
    SQS -.-> DLQ
    ALB --> Task1 & Task2
    Task1 & Task2 --> AMP
    Task1 & Task2 --> XRay
    AMP --> AMG
    AMG --> S3
    Task1 & Task2 --> SM
    Consul -->|"config + discovery"| Task1 & Task2
    ConsulSidecar -->|"sidecar"| Task1 & Task2
```

---

## ☁️ Terraform (AWS ECS)

### Arquivos e Recursos:

| Arquivo | Recursos AWS |
|---------|-------------|
| `main.tf` | Provider, backend config |
| `variables.tf` | Variáveis reutilizáveis |
| `outputs.tf` | Outputs (ALB DNS, etc.) |
| `vpc.tf` | VPC, Subnets, NAT Gateway, Route Tables |
| `ecr.tf` | ECR Repository |
| `ecs.tf` | ECS Cluster, Task Definition, Service |
| `alb.tf` | ALB, Target Group, Listener |
| `documentdb.tf` | DocumentDB Cluster, Instance |
| `sqs.tf` | SQS Queue + DLQ |
| `iam.tf` | ECS Task Role, Execution Role |
| `cloudwatch.tf` | Log Groups, Alarms |
| `consul.tf` | Consul Cluster (ECS Fargate), Config KV |
| `secretsmanager.tf` | AWS Secrets Manager |
| `prometheus.tf` | Amazon Managed Prometheus |
| `grafana.tf` | Amazon Managed Grafana |
| `s3.tf` | S3 Bucket (Thanos metrics) |
| `xray.tf` | AWS X-Ray Group |

### Diagrama de Deploy AWS:

```mermaid
graph TB
    subgraph "AWS Cloud - sa-east-1"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets"
                ALB["ALB"]
                NAT["NAT Gateway"]
            end
            subgraph "Private Subnets - Application"
                ECS["ECS Cluster"]
                Task1["Task: transaction-api<br/>(2 vCPU, 4GB)"]
                Task2["Task: transaction-api<br/>(2 vCPU, 4GB)"]
                ConsulSidecar["Consul Sidecar<br/>(config + discovery)"]
            end
            subgraph "Private Subnets - Data"
                DocDB[("DocumentDB<br/>db.r6g.large")]
            end
        end
        
        ECR["ECR<br/>transaction-api"]
        SQS["SQS<br/>conta-bancaria-criada"]
        DLQ["SQS DLQ<br/>conta-bancaria-criada-dlq"]
        CW["CloudWatch<br/>Logs & Alarms"]
        IAM["IAM Roles"]
        Consul["Consul<br/>(Config + Discovery)"]
    end
    
    ECR --> ECS
    ECS --> Task1 & Task2
    Task1 & Task2 --> DocDB
    SQS --> Task1 & Task2
    SQS -.-> DLQ
    ALB --> Task1 & Task2
    Consul -->|"config + discovery"| Task1 & Task2
    ConsulSidecar -->|"sidecar"| Task1 & Task2
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions

```mermaid
graph LR
    subgraph "CI Pipeline"
        A[Push/PR] --> B[Build<br/>mvn clean package]
        B --> C[Unit Tests<br/>mvn test]
        C --> D[Coverage Check<br/>JaCoCo ≥ 80%]
        D --> E[Integration Tests<br/>TestContainers]
        E --> F[Build Docker Image]
        F --> G[Push to ECR]
    end
    
    subgraph "CD Pipeline"
        G --> H{Branch?}
        H -->|develop| I[Deploy Staging<br/>ECS Service Update]
        H -->|main| J[Deploy Production<br/>Blue/Green]
    end
```

### Arquivos:
- `.github/workflows/ci.yml` – Build + Test + Coverage
- `.github/workflows/cd-staging.yml` – Deploy staging (auto on develop)
- `.github/workflows/cd-production.yml` – Deploy production (manual approval)

---

## 📝 Dependências Principais (Maven)

```xml
<!-- Spring Boot Parent -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.2</version>
</parent>

<!-- Kotlin version -->
<kotlin.version>2.0.0</kotlin.version>

<!-- Dependências -->
- spring-boot-starter-web          # REST API
- spring-boot-starter-data-mongodb # MongoDB
- spring-boot-starter-actuator     # Health checks / Metrics
- spring-boot-starter-validation   # Bean Validation
- spring-boot-starter-aop          # AOP para Circuit Breaker
- resilience4j-spring-boot3        # Circuit Breaker + Retry
- software.amazon.awssdk:sqs       # AWS SQS SDK v2
- spring-cloud-aws-spring-boot-starter-sqs # AWS SQS Spring integration
- jackson-module-kotlin            # JSON Kotlin support
- kotlin-stdlib                    # Kotlin stdlib
- org.mockito:mockito-core           # Mocking para unit tests
- org.mockito:mockito-junit-jupiter  # Integração Mockito + JUnit 5
- org.assertj:assertj-core           # Assertions fluentes
- org.junit.jupiter:junit-jupiter    # JUnit 5
- org.springframework.boot:spring-boot-starter-test
- testcontainers:mongodb             # Integration tests (real MongoDB)
- testcontainers:junit-jupiter       # TestContainers JUnit
- jacoco-maven-plugin                # Code coverage
```

---

## 📖 README.md Conteúdo

O README deve conter:

1. **Nome do Projeto e Descrição**
2. **Arquitetura** (diagrama Mermaid)
3. **Pré-requisitos** (Java 21, Maven, Docker)
4. **Execução Local** (docker-compose up)
5. **Endpoints da API** (documentação Swagger)
6. **Estrutura do Projeto** (DDD)
7. **Padrões de Resiliência** (Circuit Breaker, DLQ, Retry)
8. **Testes** (como rodar, cobertura)
9. **Deploy na AWS** (Terraform)
10. **CI/CD** (GitHub Actions)
11. **Decisões Arquiteturais** (ADR)
12. **Scripts de Apoio** (instruções de uso)
13. **Observabilidade** (dashboards, métricas, logs, traces)

---

## 📖 Instruções de Observabilidade para README.md

### Acesso aos Dashboards

#### URLs de Acesso

| Serviço | URL | Credenciais | Descrição |
|---------|-----|-------------|-----------|
| **Grafana** | http://localhost:3000 | admin / admin123 | Dashboards e métricas |
| **Prometheus** | http://localhost:9090 | - | Consulta direta de métricas |
| **Jaeger** | http://localhost:16686 | - | Distributed tracing |
| **Loki** | http://localhost:3100 | - | Logs estruturados |

### Dashboards Grafana

Ao acessar http://localhost:3000, navegue em **Dashboards** → **transaction-api** para ver os 3 dashboards disponíveis:

#### Dashboard: Transaction API Overview

Painéis principais:

| Painel | Descrição |
|--------|-----------|
| **Transaction Success Rate** | Taxa de sucesso das transações (%) |
| **Authorization Latency P50/P90/P95** | Latência de autorização por percentil |
| **Transactions per Second** | Transações processadas por segundo |
| **Circuit Breaker State** | Estado atual do Circuit Breaker (CLOSED/OPEN/HALF_OPEN) |
| **SQS Consumer Lag** | Atraso no consumo de mensagens SQS |
| **DLQ Messages** | Mensagens reprocessadas da Dead Letter Queue |

#### Dashboard: DLQ Monitoring

Painéis:

| Painel | Descrição |
|--------|-----------|
| **DLQ Messages Received** | Mensagens que foram para a DLQ |
| **DLQ Reprocess Success Rate** | Taxa de sucesso do reprocessamento |
| **DLQ Reprocess Latency** | Latência do reprocessamento |
| **DLQ Messages Remaining** | Mensagens pendentes na DLQ |

#### Dashboard: Infrastructure

Painéis:

| Painel | Descrição |
|--------|-----------|
| **JVM Memory Used** | Uso de memória heap/non-heap |
| **JVM GC Pause** | Pausas do garbage collector |
| **CPU Usage** | Uso de CPU |
| **HTTP Request Rate** | Taxa de requests HTTP |
| **HTTP Response Time** | Tempo de resposta HTTP (P50/P90/P95) |
| **MongoDB Query Latency** | Latência de queries ao MongoDB |

### Queries Prometheus (Exemplos)

Acesse http://localhost:9090 e execute as queries abaixo:

#### Métricas de Transação

```promql
# Total de transações por tipo (CREDIT/DEBIT)
transaction_total

# Taxa de transações por segundo (últimos 5min)
rate(transaction_total[5m])

# Total de transações aprovadas vs recusadas
transaction_total{status="SUCCEEDED"}
transaction_total{status="FAILED"}

# Taxa de sucesso (%)
rate(transaction_total{status="SUCCEEDED"}[5m]) / rate(transaction_total[5m]) * 100
```

#### Latência (Percentis)

```promql
# P50 (mediana) da latência de autorização
histogram_quantile(0.5, rate(transaction_authorization_latency_seconds_bucket[5m]))

# P90 da latência de autorização
histogram_quantile(0.9, rate(transaction_authorization_latency_seconds_bucket[5m]))

# P95 da latência de autorização
histogram_quantile(0.95, rate(transaction_authorization_latency_seconds_bucket[5m]))

# Média de latência
rate(transaction_authorization_latency_seconds_sum[5m]) / rate(transaction_authorization_latency_seconds_count[5m])
```

#### Circuit Breaker

```promql
# Estado do Circuit Breaker (0=CLOSED, 1=OPEN, 2=HALF_OPEN)
resilience4j_circuitbreaker_state

# Taxa de falhas do Circuit Breaker
resilience4j_circuitbreaker_failure_rate

# Número de chamadas permitidas em HALF_OPEN
resilience4j_circuitbreaker_permitted_number_of_calls_in_half_open_state
```

#### SQS e DLQ

```promql
# Mensagens SQS consumidas
sqs_messages_consumed_total

# Mensagens SQS que falharam
sqs_messages_failed_total

# Mensagens reprocessadas da DLQ
dlq_messages_reprocessed_total

# Taxa de consumo de mensagens
rate(sqs_messages_consumed_total[5m])
```

#### Infraestrutura (JVM)

```promql
# Uso de memória heap
jvm_memory_used_bytes{area="heap"}

# Memória máxima do heap
jvm_memory_max_bytes{area="heap"}

# Pausas do GC
jvm_gc_pause_seconds_sum

# Threads ativas
jvm_threads_live_threads
```

### Logs com Loki (Grafana)

Acesse http://localhost:3000 → **Explore** → selecione **Loki** como datasource.

#### Queries de Logs (LogQL)

```logql
# Todos os logs da aplicação
{container="transaction-api"}

# Apenas logs de erro
{container="transaction-api"} |= "ERROR"

# Logs de transação
{container="transaction-api"} |= "transaction" |= "authorize"

# Logs de Circuit Breaker
{container="transaction-api"} |= "CircuitBreaker"

# Logs de DLQ
{container="transaction-api"} |= "DLQ" |= "reprocess"

# Logs de autenticação
{container="transaction-api"} |= "JWT" |= "validate"

# Logs de erro nos últimos 5 minutos
{container="transaction-api"} |= "ERROR" | logfmt | timestamp >= now() - 5m

# Contagem de erros por minuto
count_over_time({container="transaction-api"} |= "ERROR" [1m])

# Taxa de erros
sum(rate({container="transaction-api"} |= "ERROR" [5m])) by (container)
```

### Distributed Tracing com Jaeger

Acesse http://localhost:16686:

1. Selecione **transaction-api** no dropdown "Service"
2. Clique em **Find Traces** para ver traces recentes
3. Clique em um trace para ver a árvore de spans

#### Exemplo de Trace

```
TraceID: abc123def456
├── HTTP POST /api/v1/transactions/{id} (200ms)
│   ├── jwt.validate (2ms)
│   ├── mongo.find account (15ms)
│   ├── transaction.authorize (50ms)
│   │   ├── circuitbreaker.execute (1ms)
│   │   └── mongo.update balance (20ms)
│   └── metrics.record (1ms)
```

### Métricas Customizadas da Aplicação

| Métrica | Tipo | Descrição | Como Consultar |
|---------|------|-----------|----------------|
| `transaction_total` | Counter | Total de transações | `transaction_total{type="CREDIT"}` |
| `transaction_authorization_latency_seconds` | Timer | Latência de autorização | `histogram_quantile(0.95, ...)` |
| `account_balance_avg` | Gauge | Saldo médio | `account_balance_avg` |
| `account_total` | Gauge | Total de contas | `account_total` |
| `sqs_messages_consumed_total` | Counter | Mensagens consumidas | `rate(sqs_messages_consumed_total[5m])` |
| `dlq_messages_reprocessed_total` | Counter | Mensagens reprocessadas | `dlq_messages_reprocessed_total` |
| `circuitbreaker_state` | Gauge | Estado do CB | `circuitbreaker_state{instance="mongoDb"}` |

### Alertas Configurados

| Alerta | Condição | Severidade |
|--------|----------|------------|
| **High Error Rate** | `rate(transaction_total{status="FAILED"}[5m]) > 0.1` | Critical |
| **High Latency P95** | `histogram_quantile(0.95, ...) > 1.0` | Warning |
| **Circuit Breaker Open** | `circuitbreaker_state = 1` | Critical |
| **DLQ Messages Growing** | `rate(dlq_messages_received_total[5m]) > 0` | Warning |
| **Low Success Rate** | `success_rate < 99%` | Critical |

---

## 🛠️ Scripts de Apoio

### Estrutura

```
scripts/
├── run-local.sh          # Roda app via docker-compose
├── build.sh              # Build completo (mvn clean package)
├── test.sh               # Roda todos os testes
├── test-unit.sh          # Apenas testes unitários
├── test-integration.sh   # Apenas testes de integração
├── coverage.sh           # Gera relatório de cobertura
├── seed-accounts.sh      # Popula SQS com contas de teste
└── check-queue.sh        # Verifica mensagens na fila
```

### scripts/run-local.sh

```bash
#!/bin/bash
set -e

echo "🚀 Iniciando ambiente local..."
echo "   - LocalStack (SQS)"
echo "   - MongoDB"
echo "   - Transaction API"
echo ""

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Inicie o Docker e tente novamente."
    exit 1
fi

# Para containers anteriores
docker compose down -v 2>/dev/null || true

# Sobe todos os serviços
docker compose up -d --build

echo ""
echo "⏳ Aguardando serviços ficarem saudáveis..."
echo ""

# Aguarda healthcheck da API
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo "✅ API está rodando em http://localhost:8080"
        echo "   - Swagger UI: http://localhost:8080/swagger-ui.html"
        echo "   - Health Check: http://localhost:8080/actuator/health"
        echo ""
        echo "📋 Para gerar um token de autenticação:"
        echo '   curl -X POST http://localhost:8080/api/v1/auth/token \'
        echo '     -H "Content-Type: application/json" \'
        echo '     -d '"'"'{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'"'"''
        echo ""
        echo "📋 Para verificar a fila SQS:"
        echo "   ./scripts/check-queue.sh"
        echo ""
        echo "📋 Para popular contas de teste:"
        echo "   ./scripts/seed-accounts.sh"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Tentativa $RETRY_COUNT/$MAX_RETRIES..."
    sleep 5
done

echo "❌ API não ficou saudável após $MAX_RETRIES tentativas."
echo "   Verifique os logs: docker compose logs transaction-api"
exit 1
```

### scripts/build.sh

```bash
#!/bin/bash
set -e

echo "🔨 Buildando projeto..."
echo ""

# Verifica Java
if ! java -version 2>&1 | grep -q "21"; then
    echo "❌ Java 21 não encontrado. Instale o JDK 21."
    exit 1
fi

# Verifica Maven
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven não encontrado. Instale o Maven 3.9+."
    exit 1
fi

# Build completo
echo "📦 Executando mvn clean package..."
mvn clean package -B

echo ""
echo "✅ Build concluído com sucesso!"
echo "   JAR: transaction-api/target/*.jar"
```

### scripts/test.sh

```bash
#!/bin/bash
set -e

echo "🧪 Rodando todos os testes..."
echo ""

mvn test -B

echo ""
echo "✅ Todos os testes passaram!"
```

### scripts/test-unit.sh

```bash
#!/bin/bash
set -e

echo "🧪 Rodando testes unitários..."
echo ""

mvn test -B -Dtest="*Test" -DfailIfNoTests=false

echo ""
echo "✅ Testes unitários passaram!"
```

### scripts/test-integration.sh

```bash
#!/bin/bash
set -e

echo "🧪 Rodando testes de integração (TestContainers)..."
echo ""

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. TestContainers precisa de Docker."
    exit 1
fi

mvn test -B -Dtest="*IntegrationTest" -DfailIfNoTests=false

echo ""
echo "✅ Testes de integração passaram!"
```

### scripts/coverage.sh

```bash
#!/bin/bash
set -e

echo "📊 Gerando relatório de cobertura..."
echo ""

mvn test jacoco:report -B

echo ""
echo "✅ Relatório gerado!"
echo "   Abrir: transaction-api/target/site/jacoco/index.html"
echo ""
echo "📊 Verificando cobertura mínima (80%)..."
mvn jacoco:check -B

echo ""
echo "✅ Cobertura >= 80% verificada!"
```

### scripts/seed-accounts.sh

```bash
#!/bin/bash
set -e

echo "🌱 Populando SQS com contas de teste..."
echo ""

# Verifica AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale o AWS CLI."
    exit 1
fi

# Verifica se LocalStack está rodando
if ! curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack não está rodando. Execute: docker compose up -d localstack"
    exit 1
fi

# Gera 10 contas de teste
for i in $(seq 1 10); do
    ACCOUNT_ID=$(uuidgen)
    OWNER_ID=$(uuidgen)
    CREATED_AT=$(date +%s)
    
    aws --endpoint-url=http://localhost:4566 \
        --region sa-east-1 \
        sqs send-message \
        --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
        --message-body "{\"account\":{\"id\":\"$ACCOUNT_ID\",\"owner\":\"$OWNER_ID\",\"created_at\":\"$CREATED_AT\",\"status\":\"ENABLED\"}}" \
        --message-content-type "application/json"
    
    echo "   ✅ Conta $i: $ACCOUNT_ID"
done

echo ""
echo "✅ 10 contas de teste enviadas para SQS!"
echo "   Fila: http://localhost:4566/000000000000/conta-bancaria-criada"
```

### scripts/check-queue.sh

```bash
#!/bin/bash
set -e

echo "📨 Verificando fila SQS..."
echo ""

# Verifica AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale o AWS CLI."
    exit 1
fi

# Verifica se LocalStack está rodando
if ! curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack não está rodando. Execute: docker compose up -d localstack"
    exit 1
fi

echo "📋 Fila principal (conta-bancaria-criada):"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible 2>/dev/null || echo "   Fila não encontrada"

echo ""
echo "📋 Fila DLQ (conta-bancaria-criada-dlq):"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada-dlq \
    --attribute-names ApproximateNumberOfMessages 2>/dev/null || echo "   Fila não encontrada"

echo ""
echo "📋 Últimas 5 mensagens da fila principal:"
aws --endpoint-url=http://localhost:4566 \
    --region sa-east-1 \
    sqs receive-message \
    --queue-url http://localhost:4566/000000000000/conta-bancaria-criada \
    --max-number-of-messages 5 2>/dev/null || echo "   Nenhuma mensagem"
```

---

## 📄 .gitignore

```gitignore
# Build
target/
build/
*.class
*.jar
*.war

# IDE
.idea/
*.iml
.vscode/
.settings/
.project
.classpath

# Maven
.mvn/
mvnw
mvnw.cmd

# Docker
docker-compose.override.yml

# Environment
.env
*.env.local

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Test
*.test
test-output/

# Coverage
jacoco.exec
**/jacoco.exec

# Terraform
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/*.tfvars
!terraform/environments/*.tfvars

# Spec files (NOT to be committed - contain challenge branding)
*Desafio técnico*
*autorização de transações*
*Case autorização*

# Docker volumes (persistent data - NOT to be committed)
data/
!data/.gitkeep

# AWS
.aws/
credentials
```

---

## 📋 Instruções de Uso (para README.md)

### Pré-requisitos

| Ferramenta | Versão | Comando de verificação |
|-----------|--------|----------------------|
| Java | 21+ | `java -version` |
| Maven | 3.9+ | `mvn -version` |
| Docker | 24+ | `docker --version` |
| Docker Compose | v2+ | `docker compose version` |
| AWS CLI | 2+ | `aws --version` |

### Execução Local

```bash
# 1. Clonar o repositório
git clone https://github.com/ocborghi/desafiodecdigoita.git
cd desafiodecdigoita

# 2. Rodar ambiente local (Docker)
./scripts/run-local.sh

# 3. Gerar token de autenticação
curl -X POST http://localhost:8080/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id":"transaction-api-client","client_secret":"super-secret-key-123"}'

# 4. Popular contas de teste
./scripts/seed-accounts.sh

# 5. Testar transação (usar token do passo 3)
curl -X POST http://localhost:8080/api/v1/transactions/$(uuidgen) \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"account_id":"<ACCOUNT_ID>","type":"CREDIT","amount":{"value":100.00,"currency":"BRL"}}'
```

### Rodar Testes

```bash
# Todos os testes
./scripts/test.sh

# Apenas unitários
./scripts/test-unit.sh

# Apenas integração
./scripts/test-integration.sh

# Cobertura
./scripts/coverage.sh
```

### Build

```bash
./scripts/build.sh
```

### Verificar Fila SQS

```bash
./scripts/check-queue.sh
```

### Testar com Postman

#### Pré-requisitos

1. Ter o Postman instalado (Desktop ou Web)
2. Ter a aplicação rodando via `./scripts/run-local.sh`
3. Importar a collection `postman/TransactionAPI.postman_collection.json`

#### Passo 1: Gerar Token de Autenticação

1. Abra o Postman
2. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/auth/token`
   - **Headers:** `Content-Type: application/json`
   - **Body (raw JSON):**
     ```json
     {
       "client_id": "transaction-api-client",
       "client_secret": "super-secret-key-123"
     }
     ```
3. Clique em **Send**
4. Copie o valor do campo `token` da resposta
5. Salve como variável de ambiente `{{TOKEN}}` no Postman

#### Passo 2: Popular Contas de Teste

1. Execute o script `./scripts/seed-accounts.sh` no terminal
2. Ou crie uma request no Postman:
   - **Method:** `POST`
   - **URL:** `http://localhost:4566/000000000000/conta-bancaria-criada`
   - **Headers:** `Content-Type: application/json`
   - **Body:**
     ```json
     {
       "account": {
         "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
         "owner": "315e3cfe-f4af-4cd2-b298-a449e614349a",
         "created_at": "1634874339",
         "status": "ENABLED"
       }
     }
     ```
3. Aguarde a aplicação consumir a mensagem (verifique os logs)

#### Passo 3: Testar Transação de Crédito

1. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/transactions/{{TRANSACTION_ID}}`
   - **Headers:**
     - `Content-Type: application/json`
     - `Authorization: Bearer {{TOKEN}}`
   - **Body (raw JSON):**
     ```json
     {
       "account_id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
       "type": "CREDIT",
       "amount": {
         "value": 100.00,
         "currency": "BRL"
       }
     }
     ```
2. Clique em **Send**
3. **Resposta esperada (200 OK):**
   ```json
   {
     "transaction": {
       "id": "8e8ae808-b154-48b5-9f3e-553935cc4543",
       "type": "CREDIT",
       "amount": {
         "value": 100.00,
         "currency": "BRL"
       },
       "status": "SUCCEEDED",
       "timestamp": "2025-07-08T15:57:55-03:00"
     },
     "account": {
       "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
       "balance": {
         "amount": 100.00,
         "currency": "BRL"
       }
     }
   }
   ```

#### Passo 4: Testar Transação de Débito

1. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/transactions/{{TRANSACTION_ID}}`
   - **Headers:**
     - `Content-Type: application/json`
     - `Authorization: Bearer {{TOKEN}}`
   - **Body (raw JSON):**
     ```json
     {
       "account_id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
       "type": "DEBIT",
       "amount": {
         "value": 50.00,
         "currency": "BRL"
       }
     }
     ```
2. Clique em **Send**
3. **Resposta esperada (200 OK):**
   ```json
   {
     "transaction": {
       "id": "...",
       "type": "DEBIT",
       "amount": {
         "value": 50.00,
         "currency": "BRL"
       },
       "status": "SUCCEEDED",
       "timestamp": "..."
     },
     "account": {
       "id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
       "balance": {
         "amount": 50.00,
         "currency": "BRL"
       }
     }
   }
   ```

#### Passo 5: Testar Débito com Saldo Insuficiente

1. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/transactions/{{TRANSACTION_ID}}`
   - **Headers:**
     - `Content-Type: application/json`
     - `Authorization: Bearer {{TOKEN}}`
   - **Body (raw JSON):**
     ```json
     {
       "account_id": "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975",
       "type": "DEBIT",
       "amount": {
         "value": 200.00,
         "currency": "BRL"
       }
     }
     ```
2. Clique em **Send**
3. **Resposta esperada (422 Unprocessable Entity):**
   ```json
   {
     "error": "INSUFFICIENT_BALANCE",
     "message": "Account has insufficient balance for debit transaction. Current: 50.00, Requested: 200.00",
     "timestamp": "..."
   }
   ```

#### Passo 6: Testar Conta Inexistente

1. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/transactions/{{TRANSACTION_ID}}`
   - **Headers:**
     - `Content-Type: application/json`
     - `Authorization: Bearer {{TOKEN}}`
   - **Body (raw JSON):**
     ```json
     {
       "account_id": "non-existent-account-id",
       "type": "CREDIT",
       "amount": {
         "value": 100.00,
         "currency": "BRL"
       }
     }
     ```
2. Clique em **Send**
3. **Resposta esperada (422 Unprocessable Entity):**
   ```json
   {
     "error": "ACCOUNT_NOT_FOUND",
     "message": "Account with id non-existent-account-id was not found",
     "timestamp": "..."
   }
   ```

#### Passo 7: Testar Acesso Sem Token

1. Crie uma nova request:
   - **Method:** `POST`
   - **URL:** `http://localhost:8080/api/v1/transactions/{{TRANSACTION_ID}}`
   - **Headers:** `Content-Type: application/json`
   - **Body:** (mesmo body do passo 3)
2. Clique em **Send**
3. **Resposta esperada (401 Unauthorized):**
   ```json
   {
     "error": "UNAUTHORIZED",
     "message": "Missing or invalid Authorization header",
     "timestamp": "..."
   }
   ```

#### Passo 8: Testar Swagger UI

1. Abra no navegador: `http://localhost:8080/swagger-ui.html`
2. Clique em **Authorize** no topo
3. Insira o token: `Bearer {{TOKEN}}`
4. Teste os endpoints diretamente pelo Swagger

#### Variáveis de Ambiente Postman

| Variável | Valor | Descrição |
|----------|-------|-----------|
| `BASE_URL` | `http://localhost:8080` | URL base da API |
| `TOKEN` | `eyJhbGci...` | JWT token (obtido no passo 1) |
| `ACCOUNT_ID` | `5b19c8b6-0cc4-4c72-a989-0c2ee15fa975` | ID da conta de teste |
| `TRANSACTION_ID` | `uuidgen` | ID da transação (gerar novo a cada request) |

#### Collection Postman (JSON)

A collection será criada em `postman/TransactionAPI.postman_collection.json` com:

```
📁 Transaction API
├── 🔑 Auth
│   └── POST /api/v1/auth/token
├── 💰 Transactions
│   ├── POST /api/v1/transactions/{transactionId} (CREDIT)
│   ├── POST /api/v1/transactions/{transactionId} (DEBIT)
│   ├── POST /api/v1/transactions/{transactionId} (INSUFFICIENT_BALANCE)
│   └── POST /api/v1/transactions/{transactionId} (ACCOUNT_NOT_FOUND)
├── 🏦 Accounts
│   └── POST /api/v1/accounts (via SQS - seed)
└── 📊 Health
    └── GET /actuator/health
```

---

## 📡 Telemetria, Observabilidade e Rastreamento

### Visão Geral

A aplicação implementa um stack completo de observabilidade:

| Camada | Ferramenta | Função |
|--------|------------|--------|
| **Métricas** | Prometheus + Thanos | Coleta e armazenamento de métricas |
| **Dashboards** | Grafana | Visualização de dashboards com percentis P50/P90/P95 |
| **Tracing** | OpenTelemetry + Jaeger | Rastreamento distribuído (distributed tracing) |
| **Logs** | OpenTelemetry + Loki | Logs estruturados correlacionados com traces |
| **Alertas** | Thanos Ruler / Grafana Alerts | Alertas baseados em métricas |

### Arquitetura de Observabilidade

```mermaid
graph TB
    subgraph "Aplicação (Spring Boot)"
        App["transaction-api"]
        Micrometer["Micrometer<br/>(metrics export)"]
        OTel["OpenTelemetry<br/>SDK (tracing)"]
    end
    
    subgraph "Observability Stack (Docker / AWS)"
        Prometheus["Prometheus<br/>(scrape metrics)"]
        Thanos["Thanos<br/>(long-term storage)"]
        ThanosStore["Thanos Store<br/>(S3 / local)"]
        Grafana["Grafana<br/>(dashboards)"]
        Jaeger["Jaeger<br/>(distributed tracing)"]
        Loki["Loki<br/>(logs aggregation)"]
    end
    
    subgraph "AWS Services"
        ManagedPrometheus["Amazon Managed<br/>Prometheus"]
        ManagedGrafana["Amazon Managed<br/>Grafana"]
        S3["S3<br/>(Thanos metrics)"]
        XRay["AWS X-Ray<br/>(tracing)"]
    end
    
    App --> Micrometer
    App --> OTel
    Micrometer -->|"metrics (pull)"| Prometheus
    OTel -->|"traces (push)"| Jaeger
    OTel -->|"logs (push)"| Loki
    Prometheus --> Thanos
    Thanos --> ThanosStore
    ThanosStore --> S3
    Grafana --> Prometheus
    Grafana --> Thanos
    Grafana --> Jaeger
    Grafana --> Loki
    
    Note over Grafana: Dashboards com<br/>P50, P90, P95 percentis
```

### Dependências Maven (Observabilidade)

```xml
<!-- Micrometer + Prometheus -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>

<!-- OpenTelemetry -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-trace-jaeger</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
</dependency>
```

### Métricas Customizadas da Aplicação

```kotlin
@Component
class TransactionMetrics(
    private val meterRegistry: MeterRegistry
) {
    // Counter: total de transações
    fun recordTransaction(type: String, status: String) {
        Counter.builder("transaction.total")
            .tag("type", type)           // CREDIT ou DEBIT
            .tag("status", status)       // SUCCEEDED ou FAILED
            .register(meterRegistry)
            .increment()
    }

    // Timer: latência da autorização
    fun <T> recordAuthorizationLatency(block: () -> T): T {
        return Timer.builder("transaction.authorization.latency")
            .publishPercentiles(0.5, 0.9, 0.95)  // P50, P90, P95
            .register(meterRegistry)
            .record(block)
    }

    // Gauge: saldo médio das contas
    fun recordBalanceGauge(accounts: List<Double>) {
        Gauge.builder("account.balance.avg") { accounts.average() }
            .register(meterRegistry)
    }
}
```

### Métricas Disponíveis

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `transaction.total` | Counter | Total de transações (tags: type, status) |
| `transaction.authorization.latency` | Timer | Latência de autorização (P50, P90, P95) |
| `transaction.authorization.latency.histogram` | Histogram | Histograma de latência |
| `account.balance.avg` | Gauge | Saldo médio das contas |
| `account.total` | Gauge | Total de contas registradas |
| `sqs.messages.consumed` | Counter | Mensagens SQS consumidas |
| `sqs.messages.failed` | Counter | Mensagens SQS que falharam |
| `dlq.messages.reprocessed` | Counter | Mensagens reprocessadas da DLQ |
| `circuitbreaker.state` | Gauge | Estado do Circuit Breaker |
| `jvm.memory.used` | Gauge | Uso de memória JVM |
| `jvm gc.pause` | Timer | Pausas do GC |

### Dashboards Grafana

#### Dashboard: Transaction API Overview

```json
{
  "dashboard": {
    "title": "Transaction API - Overview",
    "panels": [
      {
        "title": "Transaction Success Rate",
        "type": "stat",
        "targets": [{
          "expr": "rate(transaction_total{status=\"SUCCEEDED\"}[5m]) / rate(transaction_total[5m]) * 100"
        }]
      },
      {
        "title": "Authorization Latency P50/P90/P95",
        "type": "timeseries",
        "targets": [
          {"expr": "histogram_quantile(0.5, rate(transaction_authorization_latency_seconds_bucket[5m]))"},
          {"expr": "histogram_quantile(0.9, rate(transaction_authorization_latency_seconds_bucket[5m]))"},
          {"expr": "histogram_quantile(0.95, rate(transaction_authorization_latency_seconds_bucket[5m]))"}
        ]
      },
      {
        "title": "Transactions per Second",
        "type": "timeseries",
        "targets": [{
          "expr": "rate(transaction_total[5m])"
        }]
      },
      {
        "title": "SQS Consumer Lag",
        "type": "timeseries",
        "targets": [{
          "expr": "sqs_messages_consumed_total"
        }]
      },
      {
        "title": "Circuit Breaker State",
        "type": "stat",
        "targets": [{
          "expr": "resilience4j_circuitbreaker_state"
        }]
      },
      {
        "title": "DLQ Messages",
        "type": "timeseries",
        "targets": [{
          "expr": "dlq_messages_reprocessed_total"
        }]
      }
    ]
  }
}
```

### OpenTelemetry - Distributed Tracing

```yaml
# application.yml
management:
  tracing:
    sampling:
      probability: 1.0  # 100% para desenvolvimento, 0.1 para produção

otel:
  service:
    name: transaction-api
    version: 1.0.0
  exporter:
    otlp:
      endpoint: http://jaeger:4317
      protocol: grpc
    traces:
      endpoint: http://jaeger:4318
```

#### Spans Criados Automaticamente

| Span | Operação | Descrição |
|------|----------|-----------|
| `HTTP POST /api/v1/transactions` | HTTP | Request HTTP de entrada |
| `mongo.find` | Database | Query ao MongoDB |
| `mongo.insert` | Database | Insert no MongoDB |
| `sqs.receiveMessage` | Messaging | Consumo de mensagem SQS |
| `sqs.sendMessage` | Messaging | Envio de mensagem SQS |
| `transaction.authorize` | Business | Autorização de transação |
| `account.register` | Business | Registro de conta |

#### Exemplo de Trace com Correlation

```
TraceID: abc123def456
├── Span: HTTP POST /api/v1/transactions/{id} (200ms)
│   ├── Span: jwt.validate (2ms)
│   ├── Span: mongo.find account (15ms)
│   ├── Span: transaction.authorize (50ms)
│   │   ├── Span: circuitbreaker.execute (1ms)
│   │   └── Span: mongo.update balance (20ms)
│   └── Span: metrics.record (1ms)
```

### docker-compose.yml - Observability Stack

```yaml
services:
  # --- Prometheus ---
  prometheus:
    image: prom/prometheus:v2.53.0
    container_name: prometheus
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Thanos (sidecar) ---
  thanos-sidecar:
    image: quay.io/thanos/thanos:v0.35.0
    container_name: thanos-sidecar
    command:
      - sidecar
      - --tsdb.path=/prometheus
      - --prometheus.url=http://prometheus:9090
      - --objstore.config-file=/etc/thanos/bucket.yml
    volumes:
      - prometheus_data:/prometheus
      - ./thanos/bucket.yml:/etc/thanos/bucket.yml
    depends_on:
      - prometheus

  # --- Jaeger (tracing) ---
  jaeger:
    image: jaegertracing/all-in-one:1.59
    container_name: jaeger
    ports:
      - "127.0.0.1:16686:16686"   # UI
      - "127.0.0.1:4317:4317"     # OTLP gRPC
      - "127.0.0.1:4318:4318"     # OTLP HTTP
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:14269/"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Loki (logs) ---
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "127.0.0.1:3100:3100"
    volumes:
      - ./loki/loki.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3100/ready"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Grafana ---
  grafana:
    image: grafana/grafana:11.1.0
    container_name: grafana
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    depends_on:
      prometheus:
        condition: service_healthy
      jaeger:
        condition: service_healthy
      loki:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  prometheus_data:
  loki_data:
  grafana_data:
```

### Estrutura de Configuração

```
observability/
├── prometheus/
│   └── prometheus.yml              # Scrape config
├── thanos/
│   └── bucket.yml                  # Object store config
├── loki/
│   └── loki.yml                    # Loki config
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml     # Auto-config Prometheus + Jaeger + Loki
│   │   └── dashboards/
│   │       └── dashboards.yml      # Dashboard provisioning
│   └── dashboards/
│       ├── transaction-api.json    # Dashboard principal
│       ├── dlq-monitoring.json     # Dashboard DLQ
│       └── infrastructure.json     # Dashboard infra (JVM, GC, etc.)
```

### Prometheus Configuration

```yaml
# prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'transaction-api'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['transaction-api:8080']
        labels:
          app: 'transaction-api'
          environment: 'local'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

### Grafana Dashboard Provisioning

```yaml
# grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686

  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
```

### URLs de Acesso (Local)

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin123 |
| Prometheus | http://localhost:9090 | - |
| Jaeger UI | http://localhost:16686 | - |
| Loki | http://localhost:3100 | - |

### AWS - Managed Prometheus + Grafana

```mermaid
graph TB
    subgraph "AWS Managed Services"
        AMP["Amazon Managed<br/>Prometheus"]
        AMG["Amazon Managed<br/>Grafana"]
        S3Metrics["S3<br/>(Thanos metrics)"]
        XRay["AWS X-Ray"]
    end
    
    subgraph "ECS Tasks"
        App["transaction-api<br/>(Micrometer)"]
        OTelCollector["OTel Collector<br/>(sidecar)"]
    end
    
    App -->|"metrics"| AMP
    App -->|"traces"| OTelCollector
    OTelCollector -->|"traces"| XRay
    AMP --> AMG
    AMG -->|"dashboards"| S3Metrics
```

**Terraform para Managed Prometheus:**
```terraform
resource "aws_prometheus_workspace" "main" {
  alias = "transaction-api"
  region = var.aws_region
}
```

---

## 🔐 Gerenciamento de Senhas (Secrets Manager)

### Visão Geral

A aplicação **nunca** expõe senhas ou credenciais em texto plano. Utilizamos **AWS Secrets Manager** para armazenar secrets e **Spring Cloud AWS** para consumi-los.

### Arquitetura de Secrets

```mermaid
graph TB
    subgraph "AWS Secrets Manager"
        SecretMongo["Secret: transaction-api/mongodb"]
        SecretJWT["Secret: transaction-api/jwt"]
        SecretSQS["Secret: transaction-api/sqs"]
        SecretAPI["Secret: transaction-api/credentials"]
    end
    
    subgraph "ECS Task"
        IAMRole["IAM Role<br/>(secrets access)"]
        App["transaction-api"]
    end
    
    subgraph "Local (Docker)"
        Vault["HashiCorp Vault<br/>(dev mode)"]
        VaultUI["Vault UI<br/>(localhost:8200)"]
    end
    
    IAMRole -->|"assume role"| App
    App -->|"getSecretValue()"| SecretMongo & SecretJWT & SecretSQS & SecretAPI
    
    Vault -->|"local secrets"| App
    VaultUI -->|"manage secrets"| Vault
```

### Secrets Armazenados

| Secret Path | Conteúdo |
|-------------|----------|
| `transaction-api/mongodb` | `{"uri": "mongodb://...", "username": "...", "password": "..."}` |
| `transaction-api/jwt` | `{"secret": "...", "issuer": "transaction-api"}` |
| `transaction-api/sqs` | `{"access_key": "...", "secret_key": "...", "region": "sa-east-1"}` |
| `transaction-api/credentials` | `{"client_id": "...", "client_secret_hash": "..."}` |

### AWS Secrets Manager (Produção)

```kotlin
@Component
class SecretsManagerConfig(
    private val secretsManagerClient: SecretsManagerClient
) {
    fun getSecret(secretName: String): String {
        val request = GetSecretValueRequest.builder()
            .secretId(secretName)
            .build()
        
        return secretsManagerClient.getSecretValue(request).secretString()
    }
}

@Component
class SecretsPropertySource(
    private val secretsManagerConfig: SecretsManagerConfig,
    private val objectMapper: ObjectMapper
) {
    @Value("\${app.secrets.enabled:false}")
    private var secretsEnabled: Boolean = false

    @PostConstruct
    fun loadSecrets() {
        if (secretsEnabled) {
            val mongoSecret = secretsManagerConfig.getSecret("transaction-api/mongodb")
            val mongoProps = objectMapper.readValue(mongoSecret, Map::class.java)
            // Injeta propriedades dinamicamente
        }
    }
}
```

### HashiCorp Vault (Local/Docker)

```yaml
# docker-compose.yml - Vault
services:
  vault:
    image: hashicorp/vault:1.16
    container_name: vault
    ports:
      - "127.0.0.1:8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=root-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    command: server -dev
    healthcheck:
      test: ["CMD", "vault", "status"]
      interval: 10s
      timeout: 5s
      retries: 5

# Script para popular secrets no Vault
# scripts/seed-secrets.sh
#!/bin/bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root-token'

# MongoDB secret
vault kv put secret/transaction-api/mongodb \
  uri="mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin" \
  username="admin" \
  password="admin123"

# JWT secret
vault kv put secret/transaction-api/jwt \
  secret="MyDefaultSecretKeyForDevelopmentOnly2024!" \
  issuer="transaction-api"

# SQS secret
vault kv put secret/transaction-api/sqs \
  access_key="test" \
  secret_key="test" \
  region="sa-east-1" \
  endpoint="http://localstack:4566"

# API credentials
vault kv put secret/transaction-api/credentials \
  client_id="transaction-api-client" \
  client_secret="super-secret-key-123"
```

### Spring Cloud Vault (Local)

```yaml
# application.yml
spring:
  cloud:
    vault:
      uri: http://localhost:8200
      token: root-token
      kv:
        enabled: true
        backend: secret
        default-context: transaction-api
      secrets:
        enabled: true
```

### Configuração por Ambiente

| Ambiente | Secret Provider | Credenciais |
|----------|----------------|-------------|
| **Local** | HashiCorp Vault (dev mode) | `root-token` (fixo) |
| **Docker** | HashiCorp Vault | Volume persistido |
| **AWS Dev** | AWS Secrets Manager | IAM Role |
| **AWS Staging** | AWS Secrets Manager | IAM Role |
| **AWS Prod** | AWS Secrets Manager | IAM Role (cross-account) |

### Regras de Segurança

| Regra | Descrição |
|-------|-----------|
| **Nunca em código** | Senhas não ficam em `application.yml` em texto plano |
| **Nunca em git** | `.env` e arquivos de secrets no `.gitignore` |
| **Least privilege** | IAM Role com acesso apenas aos secrets necessários |
| **Rotation** | Secrets Manager suporta rotação automática |
| **Audit** | CloudTrail registra cada acesso a secrets |
| **Encryption** | Secrets criptografados em repouso (KMS) |

### Dependências Maven (Secrets)

```xml
<!-- AWS Secrets Manager -->
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>secretsmanager</artifactId>
</dependency>

<!-- HashiCorp Vault (local) -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-vault-config</artifactId>
</dependency>
```

---

## ⚙️ Configurações Centralizadas (Consul)

### Visão Geral

A aplicação utiliza **HashiCorp Consul** para gerenciamento centralizado de configurações, evitando deploys apenas por alteração de config. O **Hotswap** do Consul garante que alterações de configuração sejam refletidas automaticamente no Spring Boot sem reiniciar a aplicação.

### Arquitetura de Configuração

```mermaid
graph TB
    subgraph "Consul Server"
        KV["Key-Value Store<br/>(configurações)"]
        Health["Health Check<br/>(service discovery)"]
        Watch["Watch<br/>(long polling)"]
    end
    
    subgraph "Aplicação (Spring Boot)"
        App["transaction-api"]
        ConsulConfig["Spring Cloud<br/>Consul Config"]
        ConsulDiscovery["Spring Cloud<br/>Consul Discovery"]
        Hotswap["@RefreshScope<br/>(Hotswap)"]
    end
    
    subgraph "AWS"
        ConsulManaged["AWS ECS<br/>(Consul sidecar)"]
    end
    
    KV -->|"watch (long polling)"| ConsulConfig
    ConsulConfig -->|"@RefreshScope"| Hotswap
    Hotswap -->|"atualiza beans"| App
    Health -->|"service registration"| ConsulDiscovery
    ConsulDiscovery -->|"service discovery"| App
    ConsulManaged -->|"sidecar"| App
    Watch -->|"1s interval"| ConsulConfig
```

### Configurações Armazenadas no Consul

| Chave | Conteúdo | Descrição |
|-------|----------|-----------|
| `transaction-api/config/mongodb-uri` | `mongodb://admin:admin123@mongodb:27017/transaction_db` | URI do MongoDB |
| `transaction-api/config/jwt-secret` | `MyDefaultSecretKeyForDevelopmentOnly2024!` | Segredo JWT |
| `transaction-api/config/jwt-expiration` | `86400` | Expiração do token (24h) |
| `transaction-api/config/sqs-endpoint` | `http://localstack:4566` | Endpoint SQS |
| `transaction-api/config/sqs-queue` | `conta-bancaria-criada` | Nome da fila |
| `transaction-api/config/dlq-queue` | `conta-bancaria-criada-dlq` | Nome da DLQ |
| `transaction-api/config/circuit-breaker-threshold` | `50` | Threshold do CB (%) |
| `transaction-api/config/dlq-reprocessor-interval` | `PT5M` | Intervalo de reprocessamento |
| `transaction-api/config/prometheus-enabled` | `true` | Habilitar métricas |
| `transaction-api/config/otel-enabled` | `true` | Habilitar tracing |

### Dependências Maven (Consul)

```xml
<!-- Spring Cloud Consul -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-consul-config</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-consul-discovery</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bus-amqp</artifactId>
</dependency>
```

### Configuração Spring Boot (application.yml)

```yaml
spring:
  application:
    name: transaction-api
  cloud:
    consul:
      host: ${CONSUL_HOST:localhost}
      port: ${CONSUL_PORT:8500}
      config:
        enabled: true
        prefix: transaction-api
        default-context: config
        format: KEY_VALUE
        watch:
          enabled: true
          delay: 1000          # 1 segundo (hotswap)
          enabled: true
      discovery:
        enabled: true
        instance-id: ${spring.application.name}:${random.value}
        health-check-interval: 15s
        health-check-path: /actuator/health
        prefer-ip-address: true
```

### Hotswap com @RefreshScope

```kotlin
@Component
@RefreshScope
class TransactionConfig(
    @Value("\${transaction-api.config.circuit-breaker-threshold:50}")
    val circuitBreakerThreshold: Int,
    
    @Value("\${transaction-api.config.dlq-reprocessor-interval:PT5M}")
    val dlqReprocessorInterval: String,
    
    @Value("\${transaction-api.config.prometheus-enabled:true}")
    val prometheusEnabled: Boolean,
    
    @Value("\${transaction-api.config.otel-enabled:true}")
    val otelEnabled: Boolean
)
```

### Fluxo de Hotswap

```mermaid
sequenceDiagram
    participant Admin as 👤 Administrador
    participant Consul as 🗄️ Consul KV
    participant App as 🔧 transaction-api
    participant Spring as 🔄 Spring Context

    Admin->>Consul: PUT /transaction-api/config/circuit-breaker-threshold=70
    Consul->>App: Watch notification (long polling)
    App->>Spring: @RefreshScope refresh
    Spring->>Spring: Recria beans com @RefreshScope
    Spring->>App: Configuração atualizada
    Note over App: Nova config aplicada<br/>sem reiniciar a aplicação
```

### docker-compose.yml - Consul

```yaml
services:
  consul:
    image: hashicorp/consul:1.19
    container_name: consul
    ports:
      - "127.0.0.1:8500:8500"   # UI
      - "127.0.0.1:8600:8600"   # DNS
    volumes:
      - ./data/consul:/consul/data
      - ./consul/config:/consul/config
    command: agent -server -bootstrap-expect=1 -ui -client=0.0.0.0 -config-dir=/consul/config
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8500/v1/status/leader"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Script de Inicialização do Consul

```bash
# scripts/seed-consul.sh
#!/bin/bash
export CONSUL_HTTP_ADDR='http://localhost:8500'

# Configurações da aplicação
consul kv put transaction-api/config/mongodb-uri "mongodb://admin:admin123@mongodb:27017/transaction_db?authSource=admin"
consul kv put transaction-api/config/jwt-secret "MyDefaultSecretKeyForDevelopmentOnly2024!"
consul kv put transaction-api/config/jwt-expiration "86400"
consul kv put transaction-api/config/sqs-endpoint "http://localstack:4566"
consul kv put transaction-api/config/sqs-queue "conta-bancaria-criada"
consul kv put transaction-api/config/dlq-queue "conta-bancaria-criada-dlq"
consul kv put transaction-api/config/circuit-breaker-threshold "50"
consul kv put transaction-api/config/dlq-reprocessor-interval "PT5M"
consul kv put transaction-api/config/prometheus-enabled "true"
consul kv put transaction-api/config/otel-enabled "true"

echo "✅ Configurações do Consul populadas!"
```

### Teste Unitário (Consul Hotswap)

```kotlin
@ExtendWith(MockitoExtension::class)
class TransactionConfigTest {

    @Mock
    private lateinit var consulClient: ConsulClient

    @InjectMocks
    private lateinit var transactionConfig: TransactionConfig

    @Test
    fun `should load default config values`() {
        // Given
        val config = TransactionConfig(
            circuitBreakerThreshold = 50,
            dlqReprocessorInterval = "PT5M",
            prometheusEnabled = true,
            otelEnabled = true
        )

        // Then
        assertThat(config.circuitBreakerThreshold).isEqualTo(50)
        assertThat(config.dlqReprocessorInterval).isEqualTo("PT5M")
        assertThat(config.prometheusEnabled).isTrue()
        assertThat(config.otelEnabled).isTrue()
    }

    @Test
    fun `should update config via hotswap`() {
        // Given
        val config = TransactionConfig(
            circuitBreakerThreshold = 50,
            dlqReprocessorInterval = "PT5M",
            prometheusEnabled = true,
            otelEnabled = true
        )

        // When - Simula atualização via Consul
        val updatedConfig = TransactionConfig(
            circuitBreakerThreshold = 70,
            dlqReprocessorInterval = "PT10M",
            prometheusEnabled = false,
            otelEnabled = true
        )

        // Then
        assertThat(updatedConfig.circuitBreakerThreshold).isEqualTo(70)
        assertThat(updatedConfig.dlqReprocessorInterval).isEqualTo("PT10M")
        assertThat(updatedConfig.prometheusEnabled).isFalse()
    }

    @Test
    fun `should handle missing config with defaults`() {
        // Given
        val config = TransactionConfig(
            circuitBreakerThreshold = 50,
            dlqReprocessorInterval = "PT5M",
            prometheusEnabled = true,
            otelEnabled = true
        )

        // Then
        assertThat(config.circuitBreakerThreshold).isGreaterThan(0)
        assertThat(config.dlqReprocessorInterval).isNotBlank()
    }
}
```

### Teste de Integração (Consul + Spring)

```kotlin
@SpringBootTest
@Testcontainers
class ConsulConfigIntegrationTest {

    @Container
    val consul = GenericContainer("hashicorp/consul:1.19")
        .withExposedPorts(8500)
        .withCommand("agent", "-server", "-bootstrap-expect=1", "-ui", "-client=0.0.0.0")

    @DynamicPropertySource
    fun configureProperties(registry: DynamicPropertyRegistry) {
        registry.add("spring.cloud.consul.host") { consul.host }
        registry.add("spring.cloud.consul.port") { consul.firstMappedPort }
    }

    @Autowired
    private lateinit var consulClient: ConsulClient

    @Test
    fun `should read config from consul`() {
        // Given
        consulClient.putValue("transaction-api/config/circuit-breaker-threshold", "70")

        // When
        val config = consulClient.getValue("transaction-api/config/circuit-breaker-threshold")

        // Then
        assertThat(config).isEqualTo("70")
    }

    @Test
    fun `should hotswap config without restart`() {
        // Given
        consulClient.putValue("transaction-api/config/prometheus-enabled", "true")

        // When
        consulClient.putValue("transaction-api/config/prometheus-enabled", "false")

        // Then
        val config = consulClient.getValue("transaction-api/config/prometheus-enabled")
        assertThat(config).isEqualTo("false")
    }
}
```

### Consul na AWS (Terraform)

```terraform
# consul.tf
resource "aws_ecs_task_definition" "consul" {
  family = "consul"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 256
  memory = 512

  container_definitions = jsonencode([{
    name = "consul"
    image = "hashicorp/consul:1.19"
    essential = true
    portMappings = [{
      containerPort = 8500
      hostPort = 8500
    }]
    command = ["agent", "-server", "-bootstrap-expect=1", "-ui", "-client=0.0.0.0"]
  }])
}

resource "aws_ecs_service" "consul" {
  name = "consul"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consul.arn
  desired_count = 1
  launch_type = "FARGATE"
}
```

### URLs de Acesso (Local)

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Consul UI** | http://localhost:8500 | Interface de gerenciamento |
| **Consul DNS** | localhost:8600 | Service discovery via DNS |
| **Consul API** | http://localhost:8500/v1/kv/ | API REST para KV |

### Regras de Configuração

| Regra | Descrição |
|-------|-----------|
| **Nunca hardcoded** | Configurações ficam no Consul, não no application.yml |
| **Hotswap** | Alterações são refletidas sem reiniciar a aplicação |
| **Watch** | Spring Cloud Consul watch a cada 1s |
| **Health Check** | Consul verifica saúde da aplicação a cada 15s |
| **Service Discovery** | Aplicações se descobrem via Consul |
| **Audit** | Consul registra todas as alterações de configuração |
| **Config First** | Aplicação SEMPRE carrega configs do Consul antes de iniciar |
| **Fallback** | Se Consul indisponível, usa configurações locais (application.yml) |

---

## 📋 Lista de Tarefas (Task List)

### Fase 1: Setup do Projeto
- [ ] **T1.1** Inicializar repo git `desafiodecdigoita` e .gitignore
- [ ] **T1.2** Criar Parent POM (multi-module)
- [ ] **T1.3** Criar módulo `transaction-domain`
- [ ] **T1.4** Criar módulo `transaction-application`
- [ ] **T1.5** Criar módulo `transaction-infrastructure`
- [ ] **T1.6** Criar módulo `transaction-api`

### Fase 2: Domain Layer
- [ ] **T2.1** Modelar `Account`, `Transaction`, `Money` (Value Objects/Entities)
- [ ] **T2.2** Criar Enums (`TransactionType`, `TransactionStatus`, `AccountStatus`)
- [ ] **T2.3** Criar Exceptions de domínio
- [ ] **T2.4** Criar Ports (interfaces) `AccountRepositoryPort`, `TransactionRepositoryPort`, `EventPublisherPort`
- [ ] **T2.5** Implementar Domain Services (`TransactionAuthorizationService`, `AccountRegistrationService`)

### Fase 3: Application Layer
- [ ] **T3.1** Criar DTOs de request/response
- [ ] **T3.2** Implementar Mappers
- [ ] **T3.3** Implementar `AuthorizeTransactionUseCase`
- [ ] **T3.4** Implementar `RegisterAccountUseCase`
- [ ] **T3.5** Implementar `AccountCreatedConsumer` (SQS consumer)

### Fase 4: Infrastructure Layer
- [ ] **T4.1** Configurar MongoDB (documents, repositories Spring Data)
- [ ] **T4.2** Implementar `AccountRepositoryAdapter` + `TransactionRepositoryAdapter`
- [ ] **T4.3** Configurar AWS SQS (AWS SDK v2)
- [ ] **T4.4** Implementar `SqsEventPublisher` + `SqsAccountCreatedListener`
- [ ] **T4.5** Configurar Resilience4j (Circuit Breaker + Retry)
- [ ] **T4.6** Criar DLQ configuration (LocalStack + Terraform)

### Fase 5: API Layer
- [ ] **T5.1** Implementar `TransactionController` com validação
- [ ] **T5.2** Implementar `GlobalExceptionHandler`
- [ ] **T5.3** Configurar Swagger/OpenAPI
- [ ] **T5.4** Criar arquivos `application.yml`, `application-docker.yml`, `application-test.yml`

### Fase 6: Testes
- [ ] **T6.1** Testes unitários Domain Layer (≥80% cobertura)
- [ ] **T6.2** Testes unitários Application Layer
- [ ] **T6.3** Testes unitários Infrastructure Layer
- [ ] **T6.4** Testes unitários API Layer
- [ ] **T6.5** Testes de integração com TestContainers
- [ ] **T6.6** Configurar JaCoCo + verificar ≥80% coverage
- [ ] **T6.7** Criar Postman Collection

### Fase 7: Docker
- [ ] **T7.1** Criar Dockerfile multi-stage
- [ ] **T7.2** Atualizar docker-compose.yml (adicionar app + MongoDB)
- [ ] **T7.3** Testar `docker compose up` completo

### Fase 8: Terraform
- [ ] **T8.1** Criar VPC, Subnets, NAT Gateway
- [ ] **T8.2** Criar ECR Repository
- [ ] **T8.3** Criar ECS Cluster + Task Definition + Service
- [ ] **T8.4** Criar ALB + Target Group
- [ ] **T8.5** Criar DocumentDB
- [ ] **T8.6** Criar SQS + DLQ
- [ ] **T8.7** Criar IAM Roles
- [ ] **T8.8** Criar CloudWatch Logs + Alarms

### Fase 9: CI/CD
- [ ] **T9.1** Criar `.github/workflows/ci.yml`
- [ ] **T9.2** Criar `.github/workflows/cd-staging.yml`
- [ ] **T9.3** Criar `.github/workflows/cd-production.yml`

### Fase 10: Telemetria e Observabilidade
- [ ] **T10.1** Configurar Micrometer + Prometheus metrics
- [ ] **T10.2** Configurar OpenTelemetry tracing (Jaeger)
- [ ] **T10.3** Criar métricas customizadas (TransactionMetrics)
- [ ] **T10.4** Configurar Loki para logs
- [ ] **T10.5** Criar Prometheus scrape config
- [ ] **T10.6** Criar Grafana dashboards (JSON)
- [ ] **T10.7** Adicionar Jaeger ao docker-compose
- [ ] **T10.8** Adicionar Prometheus ao docker-compose
- [ ] **T10.9** Adicionar Grafana ao docker-compose
- [ ] **T10.10** Adicionar Loki ao docker-compose
- [ ] **T10.11** Configurar Thanos sidecar
- [ ] **T10.12** Provisionar datasources Grafana automaticamente

### Fase 11: Gerenciamento de Senhas
- [ ] **T11.1** Configurar HashiCorp Vault (docker-compose local)
- [ ] **T11.2** Criar script seed-secrets.sh
- [ ] **T11.3** Configurar Spring Cloud Vault
- [ ] **T11.4** Configurar AWS Secrets Manager (Terraform)
- [ ] **T11.5** Refatorar configurações para usar secrets

### Fase 12: Configurações Centralizadas (Consul)
- [ ] **T12.1** Configurar Consul (docker-compose local)
- [ ] **T12.2** Criar script seed-consul.sh
- [ ] **T12.3** Configurar Spring Cloud Consul Config
- [ ] **T12.4** Configurar Spring Cloud Consul Discovery
- [ ] **T12.5** Implementar @RefreshScope para Hotswap
- [ ] **T12.6** Criar testes unitários de configuração
- [ ] **T12.7** Criar testes de integração com Consul
- [ ] **T12.8** Configurar Consul no Terraform (AWS)

### Fase 13: Scripts de Apoio
- [ ] **T13.1** Criar `scripts/run-local.sh` (docker-compose up completo)
- [ ] **T13.2** Criar `scripts/build.sh` (mvn clean package)
- [ ] **T13.3** Criar `scripts/test.sh` / `test-unit.sh` / `test-integration.sh`
- [ ] **T13.4** Criar `scripts/coverage.sh` (JaCoCo report)
- [ ] **T13.5** Criar `scripts/seed-accounts.sh` (popular SQS com contas de teste)
- [ ] **T13.6** Criar `scripts/check-queue.sh` (verificar fila SQS)
- [ ] **T13.7** Criar `scripts/seed-secrets.sh` (popular Vault com secrets)
- [ ] **T13.8** Criar `scripts/seed-consul.sh` (popular Consul com configs)

### Fase 14: Documentação
- [ ] **T14.1** Criar README.md completo
- [ ] **T14.2** Criar ADRs (decisões arquiteturais)
- [ ] **T14.3** Criar diagramas Mermaid
- [ ] **T14.4** Commit final + push ao GitHub

---

## 🔀 Dependências entre Tarefas (para paralelização)

```
Fase 1 (Setup) ─────────────────────────────┐
                                              ▼
Fase 2 (Domain) ──► Fase 3 (Application) ──► Fase 4 (Infrastructure) ──► Fase 5 (API)
                          │                          │                          │
                          ▼                          ▼                          ▼
                    Fase 6 (Testes) ◄──────────────────────────────────────────┘
                          │
                          ▼
              Fase 7 (Docker) ──► Fase 8 (Terraform) ──► Fase 9 (CI/CD) ──► Fase 10 (Docs)
```

### Tarefas Paralelizáveis (sem dependência direta):
- **T1.3, T1.4, T1.5, T1.6** → Todos os módulos Maven podem ser criados em paralelo
- **T2.1 a T2.5** → Domain models e services (sequenciais dentro de Fase 2, mas independentes de Fases 3-5)
- **T8.1 a T8.8** → Terraform files são independentes entre si
- **T9.1 a T9.3** → Workflows CI/CD são independentes

---

## ⚡ Decisões Arquiteturais (ADR)

### ADR-001: Kotlin + Spring Boot
**Decisão:** Usar Kotlin com Spring Boot 3.3+
**Motivação:** Kotlin é mais conciso que Java, com null safety nativo e coroutines
**Trade-off:** Curva de aprendizado para quem não conhece Kotlin

### ADR-002: MongoDB (DocumentDB)
**Decisão:** Usar MongoDB como banco de dados
**Motivação:** Modelo flexível para dados bancários, compatível com AWS DocumentDB, alto throughput para operações de leitura/escrita
**Trade-off:** Transações ACID limitadas vs. relational DB (compensado com optimistic locking via version field)

### ADR-003: DDD + Multi-Module Maven
**Decisão:** Separar em módulos Domain, Application, Infrastructure, API
**Motivação:** Separação de responsabilidades, testabilidade, aderência a Clean Architecture
**Trade-off:** Mais complexidade inicial, mas escalável

### ADR-004: Resilience4j
**Decisão:** Usar Resilience4j para Circuit Breaker + Retry
**Motivação:** Padrão industry-standard, leve, bom suporte Spring Boot 3
**Trade-off:** Overhead mínimo de performance

### ADR-005: TestContainers para Integração
**Decisão:** Usar TestContainers para testes de integração com MongoDB real
**Motivação:** Testes mais confiáveis que mocks, sem dependência de infra externa
**Trade-off:** Testes de integração mais lentos (~10-30s)

### ADR-006: JaCoCo para Coverage
**Decisão:** Usar JaCoCo Maven plugin para garantir ≥80% coverage
**Motivação:** Integrado ao build, sem custo, enforcement automático
**Trade-off:** Pode exigir testes extras para atingir 80%

### ADR-007: ECS (Fargate) para Deploy
**Decisão:** Usar ECS Fargate no Terraform
**Motivação:** Serverless containers, sem gerenciamento de EC2, auto-scaling nativo
**Trade-off:** Custo ligeiramente maior que EC2, mas zero operational overhead

### ADR-008: Consul para Configurações Centralizadas
**Decisão:** Usar HashiCorp Consul para gerenciamento centralizado de configurações
**Motivação:** Evita deploys apenas por alteração de config, hotswap sem reiniciar, service discovery nativo
**Trade-off:** Mais um serviço para gerenciar, mas elimina configurações hardcoded e deploys desnecessários
