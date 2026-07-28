package com.itau.transaction.api.exception

import com.itau.transaction.domain.exception.AccountDisabledException
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.exception.InsufficientBalanceException
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.http.HttpStatus
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.MissingServletRequestParameterException
import org.springframework.web.context.request.WebRequest
import java.math.BigDecimal
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

@ExtendWith(MockitoExtension::class)
class GlobalExceptionHandlerTest {

    @InjectMocks
    private lateinit var globalExceptionHandler: GlobalExceptionHandler

    @Test
    fun `should handle AccountNotFoundException`() {
        // Given
        val exception = AccountNotFoundException("Account not found: account-123")

        // When
        val response = globalExceptionHandler.handleAccountNotFound(exception)

        // Then
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.statusCode)
        assertNotNull(response.body)
        assertEquals("ACCOUNT_NOT_FOUND", response.body?.error)
        assertNotNull(response.body?.message)
    }

    @Test
    fun `should handle AccountDisabledException`() {
        // Given
        val exception = AccountDisabledException("Account is disabled: account-789")

        // When
        val response = globalExceptionHandler.handleAccountDisabled(exception)

        // Then
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.statusCode)
        assertNotNull(response.body)
        assertEquals("ACCOUNT_DISABLED", response.body?.error)
    }

    @Test
    fun `should handle InsufficientBalanceException`() {
        // Given
        val exception = InsufficientBalanceException(BigDecimal("100.00"), BigDecimal("200.00"))

        // When
        val response = globalExceptionHandler.handleInsufficientBalance(exception)

        // Then
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.statusCode)
        assertNotNull(response.body)
        assertEquals("INSUFFICIENT_BALANCE", response.body?.error)
    }

    @Test
    fun `should handle generic Exception`() {
        // Given
        val exception = RuntimeException("Unexpected error")

        // When
        val response = globalExceptionHandler.handleGeneric(exception)

        // Then
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.statusCode)
        assertNotNull(response.body)
        assertEquals("INTERNAL_ERROR", response.body?.error)
    }
}