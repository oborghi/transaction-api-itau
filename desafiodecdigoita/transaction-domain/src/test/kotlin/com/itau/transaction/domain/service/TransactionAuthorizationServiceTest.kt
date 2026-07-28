package com.itau.transaction.domain.service

import com.itau.transaction.domain.exception.AccountDisabledException
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.exception.InsufficientBalanceException
import com.itau.transaction.domain.model.*
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class TransactionAuthorizationServiceTest {

    @Mock
    private lateinit var accountRepository: AccountRepositoryPort

    @Mock
    private lateinit var transactionRepository: TransactionRepositoryPort

    @InjectMocks
    private lateinit var transactionAuthorizationService: TransactionAuthorizationService

    private lateinit var enabledAccount: Account
    private lateinit var disabledAccount: Account

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

        disabledAccount = Account(
            id = "account-789",
            owner = "owner-012",
            balance = Money(amount = BigDecimal("50.00"), currency = "BRL"),
            status = AccountStatus.DISABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )
    }

    @Test
    fun `should authorize CREDIT transaction successfully`() {
        // Given
        val transactionId = "txn-001"
        val amount = Money(amount = BigDecimal("50.00"), currency = "BRL")

        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(enabledAccount))
        doReturn(enabledAccount).`when`(accountRepository).save(any())
        doReturn(
            Transaction(
                id = transactionId,
                accountId = "account-123",
                type = TransactionType.CREDIT,
                amount = amount,
                status = TransactionStatus.SUCCEEDED,
                timestamp = Instant.now()
            )
        ).`when`(transactionRepository).save(any())

        // When
        val result = transactionAuthorizationService.authorize(
            transactionId = transactionId,
            accountId = "account-123",
            type = TransactionType.CREDIT,
            amount = amount
        )

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(transactionId)
        assertThat(result.accountId).isEqualTo("account-123")
        assertThat(result.type).isEqualTo(TransactionType.CREDIT)
        assertThat(result.status).isEqualTo(TransactionStatus.SUCCEEDED)
        assertThat(result.amount).isEqualTo(amount)

        verify(accountRepository).findById("account-123")
        verify(accountRepository).save(any())
        verify(transactionRepository).save(any())
    }

    @Test
    fun `should authorize DEBIT transaction successfully`() {
        // Given
        val transactionId = "txn-002"
        val amount = Money(amount = BigDecimal("30.00"), currency = "BRL")

        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(enabledAccount))
        doReturn(enabledAccount).`when`(accountRepository).save(any())
        doReturn(
            Transaction(
                id = transactionId,
                accountId = "account-123",
                type = TransactionType.DEBIT,
                amount = amount,
                status = TransactionStatus.SUCCEEDED,
                timestamp = Instant.now()
            )
        ).`when`(transactionRepository).save(any())

        // When
        val result = transactionAuthorizationService.authorize(
            transactionId = transactionId,
            accountId = "account-123",
            type = TransactionType.DEBIT,
            amount = amount
        )

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(transactionId)
        assertThat(result.type).isEqualTo(TransactionType.DEBIT)
        assertThat(result.status).isEqualTo(TransactionStatus.SUCCEEDED)

        verify(accountRepository).findById("account-123")
        verify(accountRepository).save(any())
        verify(transactionRepository).save(any())
    }

    @Test
    fun `should throw AccountNotFoundException when account does not exist`() {
        // Given
        whenever(accountRepository.findById("non-existent")).thenReturn(Optional.empty())

        // When & Then
        assertThatThrownBy {
            transactionAuthorizationService.authorize(
                transactionId = "txn-003",
                accountId = "non-existent",
                type = TransactionType.CREDIT,
                amount = Money(amount = BigDecimal("50.00"), currency = "BRL")
            )
        }.isInstanceOf(AccountNotFoundException::class.java)
            .hasMessageContaining("non-existent")

        verify(accountRepository).findById("non-existent")
        verify(accountRepository, never()).save(any())
        verify(transactionRepository, never()).save(any())
    }

    @Test
    fun `should throw AccountDisabledException when account is disabled`() {
        // Given
        whenever(accountRepository.findById("account-789")).thenReturn(Optional.of(disabledAccount))

        // When & Then
        assertThatThrownBy {
            transactionAuthorizationService.authorize(
                transactionId = "txn-004",
                accountId = "account-789",
                type = TransactionType.CREDIT,
                amount = Money(amount = BigDecimal("50.00"), currency = "BRL")
            )
        }.isInstanceOf(AccountDisabledException::class.java)
            .hasMessageContaining("account-789")

        verify(accountRepository).findById("account-789")
        verify(accountRepository, never()).save(any())
        verify(transactionRepository, never()).save(any())
    }

    @Test
    fun `should throw InsufficientBalanceException for DEBIT when balance is insufficient`() {
        // Given
        val amount = Money(amount = BigDecimal("200.00"), currency = "BRL")

        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(enabledAccount))

        // When & Then
        assertThatThrownBy {
            transactionAuthorizationService.authorize(
                transactionId = "txn-005",
                accountId = "account-123",
                type = TransactionType.DEBIT,
                amount = amount
            )
        }.isInstanceOf(InsufficientBalanceException::class.java)
            .hasMessageContaining("insufficient balance")

        verify(accountRepository).findById("account-123")
        verify(accountRepository, never()).save(any())
        verify(transactionRepository, never()).save(any())
    }

    @Test
    fun `should save updated account balance after CREDIT`() {
        // Given
        val transactionId = "txn-006"
        val amount = Money(amount = BigDecimal("25.50"), currency = "BRL")

        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(enabledAccount))
        doReturn(enabledAccount).`when`(accountRepository).save(any())
        doReturn(
            Transaction(
                id = transactionId,
                accountId = "account-123",
                type = TransactionType.CREDIT,
                amount = amount,
                status = TransactionStatus.SUCCEEDED,
                timestamp = Instant.now()
            )
        ).`when`(transactionRepository).save(any())

        // When
        transactionAuthorizationService.authorize(
            transactionId = transactionId,
            accountId = "account-123",
            type = TransactionType.CREDIT,
            amount = amount
        )

        // Then
        verify(accountRepository).save(any())
        verify(transactionRepository).save(any())
    }

    @Test
    fun `should save updated account balance after DEBIT`() {
        // Given
        val transactionId = "txn-007"
        val amount = Money(amount = BigDecimal("40.00"), currency = "BRL")

        whenever(accountRepository.findById("account-123")).thenReturn(Optional.of(enabledAccount))
        doReturn(enabledAccount).`when`(accountRepository).save(any())
        doReturn(
            Transaction(
                id = transactionId,
                accountId = "account-123",
                type = TransactionType.DEBIT,
                amount = amount,
                status = TransactionStatus.SUCCEEDED,
                timestamp = Instant.now()
            )
        ).`when`(transactionRepository).save(any())

        // When
        transactionAuthorizationService.authorize(
            transactionId = transactionId,
            accountId = "account-123",
            type = TransactionType.DEBIT,
            amount = amount
        )

        // Then
        verify(accountRepository).save(any())
        verify(transactionRepository).save(any())
    }
}