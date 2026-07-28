package com.itau.transaction.infrastructure.config

import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.domain.service.AccountRegistrationService
import com.itau.transaction.domain.service.TransactionAuthorizationService
import com.itau.transaction.infrastructure.security.ClientCredentials
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock

class InfrastructureConfigTest {

    @Test
    fun `DomainServiceConfig should create TransactionAuthorizationService`() {
        val config = DomainServiceConfig()
        val accountRepo = mock<AccountRepositoryPort>()
        val transactionRepo = mock<TransactionRepositoryPort>()

        val service = config.transactionAuthorizationService(accountRepo, transactionRepo)

        assertNotNull(service)
        assertTrue(service is TransactionAuthorizationService)
    }

    @Test
    fun `DomainServiceConfig should create AccountRegistrationService`() {
        val config = DomainServiceConfig()
        val accountRepo = mock<AccountRepositoryPort>()

        val service = config.accountRegistrationService(accountRepo)

        assertNotNull(service)
        assertTrue(service is AccountRegistrationService)
    }

    @Test
    fun `JacksonConfig should create ObjectMapper with Kotlin module`() {
        val config = JacksonConfig()

        val objectMapper = config.objectMapper()

        assertNotNull(objectMapper)
        // Verify Kotlin module is registered by checking it can handle Kotlin data classes
        val json = """{"id":"test","secret":"secret","roles":["API"]}"""
        val result = objectMapper.readValue(json, ClientCredentials::class.java)
        assertEquals("test", result.id)
        assertEquals("secret", result.secret)
        assertEquals(listOf("API"), result.roles)
    }

    @Test
    fun `JacksonConfig ObjectMapper should disable dates as timestamps`() {
        val config = JacksonConfig()
        val objectMapper = config.objectMapper()

        assertFalse(objectMapper.isEnabled(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS))
    }

    @Test
    fun `CircuitBreakerConfig should create CircuitBreakerRegistry`() {
        val config = CircuitBreakerConfig()

        val registry = config.circuitBreakerRegistry()

        assertNotNull(registry)
        // Verify we can get a circuit breaker from the registry
        val cb = registry.circuitBreaker("test-circuit-breaker")
        assertNotNull(cb)
        assertEquals("test-circuit-breaker", cb.name)
    }

    @Test
    fun `CircuitBreakerConfig should create multiple circuit breakers`() {
        val config = CircuitBreakerConfig()
        val registry = config.circuitBreakerRegistry()

        val cb1 = registry.circuitBreaker("cb-one")
        val cb2 = registry.circuitBreaker("cb-two")

        assertNotNull(cb1)
        assertNotNull(cb2)
        assertEquals("cb-one", cb1.name)
        assertEquals("cb-two", cb2.name)
    }

    @Test
    fun `ClientCredentials should create with correct fields`() {
        val credentials = ClientCredentials(
            id = "client-1",
            secret = "secret-1",
            roles = listOf("ADMIN", "API")
        )

        assertEquals("client-1", credentials.id)
        assertEquals("secret-1", credentials.secret)
        assertEquals(listOf("ADMIN", "API"), credentials.roles)
    }

    @Test
    fun `ClientCredentials should support equality`() {
        val cred1 = ClientCredentials("c1", "s1", listOf("API"))
        val cred2 = ClientCredentials("c1", "s1", listOf("API"))
        val cred3 = ClientCredentials("c2", "s2", listOf("ADMIN"))

        assertEquals(cred1, cred2)
        assertNotEquals(cred1, cred3)
    }

    @Test
    fun `ClientCredentials should support toString`() {
        val credentials = ClientCredentials("c1", "s1", listOf("API"))

        val str = credentials.toString()
        assertTrue(str.contains("c1"))
        assertTrue(str.contains("s1"))
    }

    @Test
    fun `ClientCredentials should support copy`() {
        val original = ClientCredentials("c1", "s1", listOf("API"))
        val copied = original.copy(id = "c2")

        assertEquals("c2", copied.id)
        assertEquals("s1", copied.secret)
        assertEquals(listOf("API"), copied.roles)
    }
}