package com.itau.transaction.application.service

import com.itau.transaction.application.dto.request.AmountRequest
import com.itau.transaction.application.dto.request.TransactionRequest
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.model.*
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.domain.service.TransactionAuthorizationService
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class AuthorizeTransactionUseCaseTest {

    @Mock
    private lateinit var transactionAuthorizationService: TransactionAuthorizationService

    @Mock
    private lateinit var accountRepository: AccountRepositoryPort

    @Mock
    private lateinit var transactionRepository: TransactionRepositoryPort

    @InjectMocks
    private lateinit var authorizeTransactionUseCase: AuthorizeTransactionUseCase

    private lateinit var enabledAccount: Account

    @BeforeEach
    fun setUp() {
        enabledAccount = Account(
            id = "account-123",
            owner = "owner-456",
            balance = Money(amount = BigDecimal("100.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )
    }

    @Test
    fun `should authorize CREDIT transaction successfully`() {
        // Given
        val transactionId = "txn-001"
        val request = TransactionRequest(
            account_id = "account-123",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        val transaction = Transaction(
            id = transactionId,
            accountId = "account-123",
            type = TransactionType.CREDIT,
            amount = Money(amount = BigDecimal("50.00"), currency = "BRL"),
            status = TransactionStatus.SUCCEEDED,
            timestamp = Instant.now(),
            createdAt = Instant.now()
        )

        val updatedAccount = Account(
            id = "account-123",
            owner = "owner-456",
            balance = Money(amount = BigDecimal("150.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 1
        )

        doReturn(transaction).`when`(transactionAuthorizationService).authorize(any(), any(), any(), any())
        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(updatedAccount))

        // When
        val result = authorizeTransactionUseCase.execute(transactionId, request)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.transaction.id).isEqualTo(transactionId)
        assertThat(result.transaction.type).isEqualTo("CREDIT")
        assertThat(result.transaction.status).isEqualTo("SUCCEEDED")
        assertThat(result.account.id).isEqualTo("account-123")
        assertThat(result.account.balance.value).isEqualTo(150.00)
    }

    @Test
    fun `should throw AccountNotFoundException when account does not exist`() {
        // Given
        val transactionId = "txn-002"
        val request = TransactionRequest(
            account_id = "non-existent",
            type = "CREDIT",
            amount = AmountRequest(value = 50.00, currency = "BRL")
        )

        doReturn(null).`when`(transactionAuthorizationService).authorize(any(), any(), any(), any())

        // When & Then
        assertThatThrownBy {
            authorizeTransactionUseCase.execute(transactionId, request)
        }.isInstanceOf(AccountNotFoundException::class.java)

        verify(accountRepository, never()).findById(any())
    }

    @Test
    fun `should authorize DEBIT transaction successfully`() {
        // Given
        val transactionId = "txn-003"
        val request = TransactionRequest(
            account_id = "account-123",
            type = "DEBIT",
            amount = AmountRequest(value = 30.00, currency = "BRL")
        )

        val transaction = Transaction(
            id = transactionId,
            accountId = "account-123",
            type = TransactionType.DEBIT,
            amount = Money(amount = BigDecimal("30.00"), currency = "BRL"),
            status = TransactionStatus.SUCCEEDED,
            timestamp = Instant.now(),
            createdAt = Instant.now()
        )

        val updatedAccount = Account(
            id = "account-123",
            owner = "owner-456",
            balance = Money(amount = BigDecimal("70.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 1
        )

        doReturn(transaction).`when`(transactionAuthorizationService).authorize(any(), any(), any(), any())
        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(updatedAccount))

        // When
        val result = authorizeTransactionUseCase.execute(transactionId, request)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.transaction.type).isEqualTo("DEBIT")
        assertThat(result.account.balance.value).isEqualTo(70.00)
    }
}