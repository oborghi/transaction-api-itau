package com.itau.transaction.api.controller

import com.itau.transaction.application.dto.request.AmountRequest
import com.itau.transaction.application.dto.request.TransactionRequest
import com.itau.transaction.application.dto.response.*
import com.itau.transaction.application.service.AuthorizeTransactionUseCase
import com.itau.transaction.domain.exception.AccountDisabledException
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.exception.InsufficientBalanceException
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.assertThrows
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.http.HttpStatus
import java.math.BigDecimal
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

@ExtendWith(MockitoExtension::class)
class TransactionControllerTest {

    @Mock
    private lateinit var authorizeTransactionUseCase: AuthorizeTransactionUseCase

    @InjectMocks
    private lateinit var transactionController: TransactionController

    @Test
    fun `should authorize transaction successfully`() {
        // Given
        val transactionId = "txn-001"
        val request = TransactionRequest(
            account_id = "account-123",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        val response = TransactionAuthorizationResponse(
            transaction = TransactionResponse(
                id = transactionId,
                type = "CREDIT",
                amount = AmountResponse(value = 50.00, currency = "BRL"),
                status = "SUCCEEDED",
                timestamp = Instant.now()
            ),
            account = AccountResponse(
                id = "account-123",
                balance = AmountResponse(value = 150.00, currency = "BRL")
            )
        )

        `when`(authorizeTransactionUseCase.execute(transactionId, request)).thenReturn(response)

        // When
        val result = transactionController.authorizeTransaction(transactionId, request)

        // Then
        assertNotNull(result)
        assertEquals(HttpStatus.OK, result.statusCode)
        assertNotNull(result.body)
        assertEquals(transactionId, result.body?.transaction?.id)
        assertEquals("CREDIT", result.body?.transaction?.type)
        assertEquals("SUCCEEDED", result.body?.transaction?.status)

        verify(authorizeTransactionUseCase).execute(transactionId, request)
    }

    @Test
    fun `should throw AccountNotFoundException when account not found`() {
        // Given
        val transactionId = "txn-002"
        val request = TransactionRequest(
            account_id = "non-existent",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        `when`(authorizeTransactionUseCase.execute(transactionId, request))
            .thenThrow(AccountNotFoundException("non-existent"))

        // When & Then
        val exception = assertThrows<AccountNotFoundException> {
            transactionController.authorizeTransaction(transactionId, request)
        }
        assertNotNull(exception.message)

        verify(authorizeTransactionUseCase).execute(transactionId, request)
    }

    @Test
    fun `should throw AccountDisabledException when account is disabled`() {
        // Given
        val transactionId = "txn-003"
        val request = TransactionRequest(
            account_id = "account-789",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        `when`(authorizeTransactionUseCase.execute(transactionId, request))
            .thenThrow(AccountDisabledException("account-789"))

        // When & Then
        val exception = assertThrows<AccountDisabledException> {
            transactionController.authorizeTransaction(transactionId, request)
        }
        assertNotNull(exception.message)

        verify(authorizeTransactionUseCase).execute(transactionId, request)
    }

    @Test
    fun `should throw InsufficientBalanceException when insufficient balance`() {
        // Given
        val transactionId = "txn-004"
        val request = TransactionRequest(
            account_id = "account-123",
            type = "DEBIT",
            amount = AmountRequest(value = 200.00, currency = "BRL")
        )

        `when`(authorizeTransactionUseCase.execute(transactionId, request))
            .thenThrow(InsufficientBalanceException(BigDecimal("100.00"), BigDecimal("200.00")))

        // When & Then
        assertThrows<InsufficientBalanceException> {
            transactionController.authorizeTransaction(transactionId, request)
        }

        verify(authorizeTransactionUseCase).execute(transactionId, request)
    }
}