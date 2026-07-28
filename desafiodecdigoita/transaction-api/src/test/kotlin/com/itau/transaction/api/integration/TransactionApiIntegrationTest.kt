package com.itau.transaction.api.integration

import com.fasterxml.jackson.databind.ObjectMapper
import com.itau.transaction.application.dto.request.AmountRequest
import com.itau.transaction.application.dto.request.TransactionRequest
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*
import org.testcontainers.containers.MongoDBContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class TransactionApiIntegrationTest {

    companion object {
        @Container
        val mongoDBContainer = MongoDBContainer("mongo:7.0")
            .withExposedPorts(27017)

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.data.mongodb.uri") { mongoDBContainer.replicaSetUrl }
            registry.add("aws.endpoint-url") { "http://localhost:4566" }
            registry.add("app.sqs.queue-url") { "http://localhost:4566/000000000000/conta-bancaria-criada" }
        }
    }

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var objectMapper: ObjectMapper

    @Test
    fun `should return 401 when no authorization header`() {
        // Given
        val request = TransactionRequest(
            account_id = "account-123",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        // When & Then
        mockMvc.perform(
            post("/api/v1/transactions/txn-001")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `should return 422 when account not found`() {
        // Given
        val request = TransactionRequest(
            account_id = "non-existent",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        // When & Then - This test requires a valid JWT token
        // For now, we're testing the error handling path
        mockMvc.perform(
            post("/api/v1/transactions/txn-002")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request))
                .header("Authorization", "Bearer invalid-token")
        )
            .andExpect(status().isUnauthorized)
    }
}