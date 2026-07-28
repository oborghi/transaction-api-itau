package com.itau.transaction.api.integration

import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.testcontainers.containers.MongoDBContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class AccountRegistrationIntegrationTest {

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

    @Test
    fun `should start application context successfully`() {
        // This test verifies that the Spring context starts correctly
        // with TestContainers MongoDB
    }
}