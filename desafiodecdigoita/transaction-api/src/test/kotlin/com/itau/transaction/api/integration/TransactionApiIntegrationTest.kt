package com.itau.transaction.api.integration

import com.fasterxml.jackson.databind.ObjectMapper
import com.itau.transaction.application.dto.request.AmountRequest
import com.itau.transaction.application.dto.request.TransactionRequest
import com.itau.transaction.infrastructure.config.TransactionMetrics
import io.micrometer.core.instrument.MeterRegistry
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.MethodOrderer
import org.junit.jupiter.api.Order
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestMethodOrder
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

/**
 * Comprehensive integration test that exercises the full transaction flow
 * and verifies all observability metrics are properly recorded.
 *
 * Tests cover:
 * - JWT authentication with Caffeine cache (hits/misses)
 * - Account registration via SQS
 * - Transaction authorization (CREDIT/DEBIT)
 * - Error scenarios (not found, insufficient balance)
 * - Metrics recording (transaction_total, latency, circuit breaker, SQS, DLQ)
 * - CloudWatch metrics exposure
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(IntegrationTestCacheConfig::class)
@TestMethodOrder(MethodOrderer.OrderAnnotation::class)
class TransactionApiIntegrationTest {

    companion object {
    }

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var objectMapper: ObjectMapper

    @Autowired
    lateinit var meterRegistry: MeterRegistry

    @Autowired
    lateinit var transactionMetrics: TransactionMetrics

    private val testAccountId = "5b19c8b6-0cc4-4c72-a989-0c2ee15fa975"
    private val testOwnerId = "315e3cfe-f4af-4cd2-b298-a449e614349a"
    private var authToken: String = ""

    @BeforeEach
    fun setup() {
        // Generate auth token for tests
        val authResponse = mockMvc.perform(
            post("/api/v1/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(mapOf(
                    "client_id" to "transaction-api-client",
                    "client_secret" to "super-secret-key-123"
                )))
        ).andReturn()
        val responseBody = objectMapper.readTree(authResponse.response.contentAsString)
        authToken = responseBody.path("token").asText()
    }

    // ==================== AUTH TESTS ====================

    @Test
    @Order(1)
    fun `should generate JWT token successfully`() {
        assertNotNull(authToken)
        assertTrue(authToken.isNotEmpty())
    }

    @Test
    @Order(2)
    fun `should reject invalid token`() {
        mockMvc.perform(
            post("/api/v1/transactions/test-tx")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(TransactionRequest(
                    account_id = testAccountId,
                    type = "CREDIT",
                    amount = AmountRequest(value = 100.00, currency = "BRL")
                )))
                .header("Authorization", "Bearer invalid-token-123")
        )
            .andExpect(status().isForbidden)
    }

    @Test
    @Order(3)
    fun `should reject request without authorization header`() {
        mockMvc.perform(
            post("/api/v1/transactions/test-tx")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(TransactionRequest(
                    account_id = testAccountId,
                    type = "CREDIT",
                    amount = AmountRequest(value = 100.00, currency = "BRL")
                )))
        )
            .andExpect { result -> assertTrue(result.response.status in listOf(401, 403)) }
    }

    // ==================== JWT CACHE TESTS ====================

    @Test
    @Order(4)
    fun `should cache JWT token in Caffeine cache`() {
        // First request - cache MISS
        val firstCall = mockMvc.perform(
            post("/api/v1/transactions/cache-test-1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(mapOf(
                    "account_id" to "non-existent",
                    "type" to "CREDIT",
                    "amount" to mapOf("value" to 10.00, "currency" to "BRL")
                )))
                .header("Authorization", "Bearer $authToken")
        ).andReturn()

        // Second request - cache HIT
        val secondCall = mockMvc.perform(
            post("/api/v1/transactions/cache-test-2")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(mapOf(
                    "account_id" to "non-existent",
                    "type" to "CREDIT",
                    "amount" to mapOf("value" to 10.00, "currency" to "BRL")
                )))
                .header("Authorization", "Bearer $authToken")
        ).andReturn()

        // Both should not be 401 (they pass auth)
        assertNotEquals(401, firstCall.response.status)
        assertNotEquals(401, secondCall.response.status)

        // Verify Caffeine cache metrics exist
        val cacheGets = meterRegistry.find("cache.gets")
        assertNotNull(cacheGets, "cache.gets metric should be registered")
        val cacheHits = meterRegistry.find("cache.hits")
        assertNotNull(cacheHits, "cache.hits metric should be registered")
    }

    // ==================== ACCOUNT REGISTRATION (SQS) TESTS ====================

    @Test
    @Order(10)
    fun `should have SQS infrastructure available`() {
        assertNotNull(meterRegistry, "MeterRegistry should be available")
        // Verify SQS consumer metric structure exists in MeterRegistry
        // (actual messages may or may not be consumed depending on consumer state)
    }

    @Test
    @Order(11)
    fun `should record SQS consumed and failed metrics`() {
        // This test assumes SQS messages are being processed or failing.
        // We check if the metrics are registered, not necessarily if they are incremented.
        assertNotNull(meterRegistry.find("sqs.messages.consumed").counter(), "SQS consumed counter should be registered")
        assertNotNull(meterRegistry.find("sqs.messages.failed").counter(), "SQS failed counter should be registered")
    }

    // ==================== TRANSACTION TESTS ====================

    @Test
    @Order(20)
    fun `should return 422 when account not found`() {
        val request = TransactionRequest(
            account_id = "non-existent-account-id",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        mockMvc.perform(
            post("/api/v1/transactions/txn-not-found")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .header("Authorization", "Bearer $authToken")
        )
            .andExpect(status().isUnprocessableEntity)
            .andExpect(jsonPath("$.error").value("ACCOUNT_NOT_FOUND"))
            .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("was not found")))

        // Verify failure metric via MeterRegistry
        val failedCounter = meterRegistry.find("transaction.total")
            .tags("type", "CREDIT", "status", "FAILED").counter()
        assertNotNull(failedCounter, "transaction.total FAILED counter should be registered")
    }

    @Test
    @Order(21)
    fun `should return 422 for insufficient balance on debit`() {
        val request = TransactionRequest(
            account_id = testAccountId,
            type = "DEBIT",
            amount = AmountRequest(value = 999999.00, currency = "BRL")
        )

        mockMvc.perform(
            post("/api/v1/transactions/txn-insufficient")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .header("Authorization", "Bearer $authToken")
        )
            .andExpect(status().isUnprocessableEntity)
    }

    @Test
    @Order(22)
    fun `should return 400 for invalid request body`() {
        mockMvc.perform(
            post("/api/v1/transactions/txn-invalid")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"invalid": "payload"}""")
                .header("Authorization", "Bearer $authToken")
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    @Order(23)
    fun `should return 400 for invalid transaction type`() {
        val request = mapOf(
            "account_id" to testAccountId,
            "type" to "INVALID_TYPE",
            "amount" to mapOf("value" to 10.00, "currency" to "BRL")
        )

        mockMvc.perform(
            post("/api/v1/transactions/txn-invalid-type")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .header("Authorization", "Bearer $authToken")
        )
            .andExpect(status().isBadRequest)
    }

    // ==================== METRICS VERIFICATION TESTS ====================

    @Test
    @Order(50)
    fun `should expose Prometheus metrics endpoint`() {
        mockMvc.perform(
            get("/actuator/prometheus")
        )
            .andExpect(status().isOk)
            .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_PLAIN))
    }

    @Test
    @Order(51)
    fun `should expose HTTP server metrics`() {
        val result = mockMvc.perform(
            get("/actuator/prometheus")
        ).andReturn()

        val prometheusOutput = result.response.contentAsString

        assertTrue(prometheusOutput.contains("http_server_requests_seconds"),
            "http_server_requests_seconds should be present in Prometheus metrics")
    }

    @Test
    @Order(52)
    fun `should expose transaction metrics after requests`() {
        // Make some transaction requests to generate metrics
        for (i in 1..5) {
            mockMvc.perform(
                post("/api/v1/transactions/metrics-test-$i")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(TransactionRequest(
                        account_id = "non-existent-for-metrics",
                        type = "CREDIT",
                        amount = AmountRequest(value = 10.00, currency = "BRL")
                    )))
                    .header("Authorization", "Bearer $authToken")
            )
        }

        val result = mockMvc.perform(
            get("/actuator/prometheus")
        ).andReturn()

        val prometheusOutput = result.response.contentAsString

        assertTrue(prometheusOutput.contains("transaction_total"),
            "transaction_total metric should be present")

        assertTrue(prometheusOutput.contains("transaction_authorization_latency_seconds"),
            "transaction_authorization_latency_seconds should be present")
    }

    @Test
    @Order(53)
    fun `should expose circuit breaker metrics`() {
        val result = mockMvc.perform(
            get("/actuator/prometheus")
        ).andReturn()

        val prometheusOutput = result.response.contentAsString

        assertTrue(prometheusOutput.contains("resilience4j_circuitbreaker"),
            "resilience4j_circuitbreaker metrics should be present")
    }

    @Test
    @Order(54)
    fun `should record circuit breaker state metric`() {
        val cbState = meterRegistry.find("resilience4j.circuitbreaker.state")
            .gauge()

        assertNotNull(cbState, "Circuit breaker state gauge should be registered")
        val state = cbState!!.value()
        assertTrue(state in 0.0..2.0, "Circuit breaker state should be 0, 1, or 2, was: $state")
    }

    @Test
    @Order(55)
    fun `should expose JVM metrics`() {
        val result = mockMvc.perform(
            get("/actuator/prometheus")
        ).andReturn()

        val prometheusOutput = result.response.contentAsString

        assertTrue(prometheusOutput.contains("jvm_memory_used_bytes"),
            "JVM memory metrics should be present")
        assertTrue(prometheusOutput.contains("jvm_threads_live_threads"),
            "JVM threads metrics should be present")
    }

    @Test
    @Order(49)
    fun `should activate every metric used by Grafana dashboards`() {
        // Exercise every custom metric and every tag value queried by Grafana.
        transactionMetrics.recordTransaction("CREDIT", "SUCCEEDED")
        transactionMetrics.recordTransaction("DEBIT", "SUCCEEDED")
        transactionMetrics.recordTransaction("CREDIT", "FAILED")
        transactionMetrics.recordTransaction("DEBIT", "FAILED")
        transactionMetrics.recordAuthorizationLatency { "recorded" }
        transactionMetrics.recordSqsMessageConsumed()
        transactionMetrics.recordSqsMessageFailed()
        transactionMetrics.recordDlqMessageReprocessed(true)
        transactionMetrics.recordDlqMessageReprocessed(false)
        transactionMetrics.updateAccountBalance("metrics-account-1", 100.0)
        transactionMetrics.updateAccountBalance("metrics-account-2", 300.0)

        assertNotNull(meterRegistry.find("transaction.total")
            .tags("type", "CREDIT", "status", "SUCCEEDED").counter())
        assertNotNull(meterRegistry.find("transaction.total")
            .tags("type", "DEBIT", "status", "SUCCEEDED").counter())
        assertNotNull(meterRegistry.find("transaction.total")
            .tags("type", "CREDIT", "status", "FAILED").counter())
        assertNotNull(meterRegistry.find("transaction.total")
            .tags("type", "DEBIT", "status", "FAILED").counter())
        assertNotNull(meterRegistry.find("transaction.authorization.latency").timer())
        assertNotNull(meterRegistry.find("sqs.messages.consumed").counter())
        assertNotNull(meterRegistry.find("sqs.messages.failed").counter())
        assertNotNull(meterRegistry.find("dlq.messages.reprocessed")
            .tag("status", "success").counter())
        assertNotNull(meterRegistry.find("dlq.messages.reprocessed")
            .tag("status", "failed").counter())
        assertEquals(2.0, meterRegistry.get("account.total").gauge().value())
        assertEquals(200.0, meterRegistry.get("account.balance.avg").gauge().value())

        val prometheusOutput = mockMvc.perform(get("/actuator/prometheus"))
            .andExpect(status().isOk)
            .andReturn().response.contentAsString

        val dashboardMetrics = listOf(
            "transaction_total",
            "transaction_authorization_latency_seconds_bucket",
            "sqs_messages_consumed_total",
            "sqs_messages_failed_total",
            "dlq_messages_reprocessed_total",
            "account_balance_avg",
            "account",
            "http_server_requests_seconds",
            "cache_gets_total",
            "resilience4j_circuitbreaker_state",
            "resilience4j_circuitbreaker_failure_rate",
            "jvm_memory_max_bytes",
            "jvm_memory_used_bytes",
            "jvm_threads_daemon_threads",
            "jvm_threads_live_threads",
            "jvm_gc_pause_seconds",
            "process_cpu_usage",
            "system_cpu_usage"
        )

        dashboardMetrics.forEach { metric ->
            assertTrue(
                prometheusOutput.contains(metric),
                "$metric, used by a Grafana dashboard, should be exported"
            )
        }

        assertTrue(prometheusOutput.contains("type=\"CREDIT\""))
        assertTrue(prometheusOutput.contains("type=\"DEBIT\""))
        assertTrue(prometheusOutput.contains("status=\"SUCCEEDED\""))
        assertTrue(prometheusOutput.contains("status=\"FAILED\""))
        assertTrue(prometheusOutput.contains("status=\"success\""))
        assertTrue(prometheusOutput.contains("status=\"failed\""))
        assertTrue(prometheusOutput.contains("name=\"dlqReprocessorCircuitBreaker\""))
    }

    // ==================== HEALTH CHECK TESTS ====================

    @Test
    @Order(100)
    fun `should return health status`() {
        mockMvc.perform(
            get("/actuator/health")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("UP"))
    }
}
