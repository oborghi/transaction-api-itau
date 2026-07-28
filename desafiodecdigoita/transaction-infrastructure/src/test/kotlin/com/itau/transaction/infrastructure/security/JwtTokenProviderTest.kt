package com.itau.transaction.infrastructure.security

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class JwtTokenProviderTest {

    private lateinit var jwtTokenProvider: JwtTokenProvider

    private val secret = "MyDefaultSecretKeyForDevelopmentOnly2024!"
    private val expiration = 86400L
    private val issuer = "transaction-api"

    @BeforeEach
    fun setUp() {
        jwtTokenProvider = JwtTokenProvider(secret, expiration, issuer)
    }

    @Test
    fun `should generate valid token`() {
        val clientId = "test-client"
        val roles = listOf("ADMIN", "API")

        val token = jwtTokenProvider.generateToken(clientId, roles)

        assertNotNull(token)
        assertTrue(token.isNotEmpty())
    }

    @Test
    fun `should validate and get subject from token`() {
        val clientId = "test-client"
        val roles = listOf("ADMIN", "API")

        val token = jwtTokenProvider.generateToken(clientId, roles)
        val subject = jwtTokenProvider.validateAndGetSubject(token)

        assertEquals(clientId, subject)
    }

    @Test
    fun `should validate token`() {
        val clientId = "test-client"
        val roles = listOf("API")

        val token = jwtTokenProvider.generateToken(clientId, roles)

        assertTrue(jwtTokenProvider.validateToken(token))
    }

    @Test
    fun `should return false for invalid token`() {
        val invalidToken = "invalid.token.here"

        assertFalse(jwtTokenProvider.validateToken(invalidToken))
    }

    @Test
    fun `should get expiration from token`() {
        val clientId = "test-client"
        val roles = listOf("ADMIN")

        val token = jwtTokenProvider.generateToken(clientId, roles)
        val expiration = jwtTokenProvider.getExpiration(token)

        assertNotNull(expiration)
        assertTrue(expiration.after(java.util.Date()))
    }

    @Test
    fun `should generate token with different roles`() {
        val clientId = "readonly-client"
        val roles = listOf("API")

        val token = jwtTokenProvider.generateToken(clientId, roles)
        val subject = jwtTokenProvider.validateAndGetSubject(token)

        assertEquals(clientId, subject)
        assertTrue(jwtTokenProvider.validateToken(token))
    }
}