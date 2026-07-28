package com.itau.transaction.infrastructure.persistence.adapter

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import com.itau.transaction.infrastructure.persistence.entity.AccountDocument
import com.itau.transaction.infrastructure.persistence.repository.AccountMongoRepository
import org.assertj.core.api.Assertions.assertThat
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
class AccountRepositoryAdapterTest {

    @Mock
    private lateinit var accountMongoRepository: AccountMongoRepository

    @InjectMocks
    private lateinit var accountRepositoryAdapter: AccountRepositoryAdapter

    private lateinit var account: Account
    private lateinit var accountDocument: AccountDocument

    @BeforeEach
    fun setUp() {
        account = Account(
            id = "account-123",
            owner = "owner-456",
            balance = Money(amount = BigDecimal("100.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )

        accountDocument = AccountDocument(
            id = "account-123",
            owner = "owner-456",
            balanceAmount = BigDecimal("100.00"),
            balanceCurrency = "BRL",
            status = "ENABLED",
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )
    }

    @Test
    fun `should find account by id`() {
        // Given
        whenever(accountMongoRepository.findById("account-123")).thenReturn(Optional.of(accountDocument))

        // When
        val result = accountRepositoryAdapter.findById("account-123")

        // Then
        assertThat(result.isPresent).isTrue()
        assertThat(result.get().id).isEqualTo("account-123")
        assertThat(result.get().owner).isEqualTo("owner-456")

        verify(accountMongoRepository).findById("account-123")
    }

    @Test
    fun `should return empty when account not found`() {
        // Given
        whenever(accountMongoRepository.findById("non-existent")).thenReturn(Optional.empty())

        // When
        val result = accountRepositoryAdapter.findById("non-existent")

        // Then
        assertThat(result.isPresent).isFalse()

        verify(accountMongoRepository).findById("non-existent")
    }

    @Test
    fun `should save account`() {
        // Given
        whenever(accountMongoRepository.save(any())).thenReturn(accountDocument)

        // When
        val result = accountRepositoryAdapter.save(account)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo("account-123")

        verify(accountMongoRepository).save(any())
    }

    @Test
    fun `should check if account exists by id`() {
        // Given
        whenever(accountMongoRepository.existsById("account-123")).thenReturn(true)

        // When
        val result = accountRepositoryAdapter.existsById("account-123")

        // Then
        assertThat(result).isTrue()

        verify(accountMongoRepository).existsById("account-123")
    }

    @Test
    fun `should return false when account does not exist`() {
        // Given
        whenever(accountMongoRepository.existsById("non-existent")).thenReturn(false)

        // When
        val result = accountRepositoryAdapter.existsById("non-existent")

        // Then
        assertThat(result).isFalse()

        verify(accountMongoRepository).existsById("non-existent")
    }
}