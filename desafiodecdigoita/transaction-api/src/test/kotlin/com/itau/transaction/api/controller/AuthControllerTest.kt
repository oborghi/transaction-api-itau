package com.itau.transaction.api.controller

import com.itau.transaction.infrastructure.security.JwtTokenProvider
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import java.util.Date

@ExtendWith(MockitoExtension::class)
class AuthControllerTest {

    @Mock
    private lateinit var jwtTokenProvider: JwtTokenProvider

    private lateinit var authController: AuthController

    @BeforeEach
    fun setUp() {
        authController = AuthController(jwtTokenProvider, "transaction-api-client", "super-secret-key-123")
    }

    @Test
    fun `should generate token for valid credentials`() {
        val request = AuthRequest(
            client_id = "transaction-api-client",
            client_secret = "super-secret-key-123"
        )
        val token = "eyJhbGciOiJIUzI1NiJ9.test.token"
        val expirationDate = Date(System.currentTimeMillis() + 86400000)

        whenever(jwtTokenProvider.generateToken(any(), any())).thenReturn(token)
        whenever(jwtTokenProvider.getExpiration(any())).thenReturn(expirationDate)

        val response = authController.generateToken(request)

        assertEquals(200, response.statusCodeValue)
        assertNotNull(response.body)
        assertEquals(token, response.body?.token)
        assertEquals("Bearer", response.body?.token_type)
        assertEquals(86400, response.body?.expires_in)
        assertNotNull(response.body?.expires_at)
    }

    @Test
    fun `should return 401 for blank client_id`() {
        val request = AuthRequest(
            client_id = "",
            client_secret = "super-secret-key-123"
        )

        val response = authController.generateToken(request)

        assertEquals(401, response.statusCodeValue)
        assertNotNull(response.body)
        assertEquals("UNAUTHORIZED", response.body?.error)
        assertEquals("Invalid client credentials", response.body?.message)
        assertNull(response.body?.token)
    }

    @Test
    fun `should return 401 for blank client_secret`() {
        val request = AuthRequest(
            client_id = "transaction-api-client",
            client_secret = ""
        )

        val response = authController.generateToken(request)

        assertEquals(401, response.statusCodeValue)
        assertNotNull(response.body)
        assertEquals("UNAUTHORIZED", response.body?.error)
        assertEquals("Invalid client credentials", response.body?.message)
    }

    @Test
    fun `should return 401 for blank client_id and client_secret`() {
        val request = AuthRequest(
            client_id = "",
            client_secret = ""
        )

        val response = authController.generateToken(request)

        assertEquals(401, response.statusCodeValue)
        assertNotNull(response.body)
        assertEquals("UNAUTHORIZED", response.body?.error)
    }

    @Test
    fun `should return 401 for invalid credentials`() {
        val request = AuthRequest(
            client_id = "wrong-client",
            client_secret = "wrong-secret"
        )

        val response = authController.generateToken(request)

        assertEquals(401, response.statusCodeValue)
        assertNotNull(response.body)
        assertEquals("UNAUTHORIZED", response.body?.error)
        assertEquals("Invalid client credentials", response.body?.message)
        assertNull(response.body?.token)
    }

    @Test
    fun `should create AuthRequest with correct fields`() {
        val request = AuthRequest(
            client_id = "client-1",
            client_secret = "secret-1"
        )

        assertEquals("client-1", request.client_id)
        assertEquals("secret-1", request.client_secret)
    }

    @Test
    fun `should create AuthResponse with token fields`() {
        val response = AuthResponse(
            token = "test-token",
            token_type = "Bearer",
            expires_in = 86400,
            expires_at = "2025-01-01T00:00:00Z"
        )

        assertEquals("test-token", response.token)
        assertEquals("Bearer", response.token_type)
        assertEquals(86400, response.expires_in)
        assertEquals("2025-01-01T00:00:00Z", response.expires_at)
        assertNull(response.error)
        assertNull(response.message)
    }

    @Test
    fun `should create AuthResponse with error fields`() {
        val response = AuthResponse(
            error = "UNAUTHORIZED",
            message = "Invalid credentials"
        )

        assertNull(response.token)
        assertNull(response.token_type)
        assertNull(response.expires_in)
        assertNull(response.expires_at)
        assertEquals("UNAUTHORIZED", response.error)
        assertEquals("Invalid credentials", response.message)
    }

    @Test
    fun `should create default AuthResponse`() {
        val response = AuthResponse()

        assertNull(response.token)
        assertNull(response.token_type)
        assertNull(response.expires_in)
        assertNull(response.expires_at)
        assertNull(response.error)
        assertNull(response.message)
    }
}