package com.itau.transaction.infrastructure.persistence.adapter

import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.model.Transaction
import com.itau.transaction.domain.model.TransactionStatus
import com.itau.transaction.domain.model.TransactionType
import com.itau.transaction.infrastructure.persistence.entity.TransactionDocument
import com.itau.transaction.infrastructure.persistence.repository.TransactionMongoRepository
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
class TransactionRepositoryAdapterTest {

    @Mock
    private lateinit var transactionMongoRepository: TransactionMongoRepository

    @InjectMocks
    private lateinit var transactionRepositoryAdapter: TransactionRepositoryAdapter

    private lateinit var transaction: Transaction
    private lateinit var transactionDocument: TransactionDocument

    @BeforeEach
    fun setUp() {
        transaction = Transaction(
            id = "txn-001",
            accountId = "account-123",
            type = TransactionType.CREDIT,
            amount = Money(amount = BigDecimal("50.00"), currency = "BRL"),
            status = TransactionStatus.SUCCEEDED,
            timestamp = Instant.now(),
            createdAt = Instant.now()
        )

        transactionDocument = TransactionDocument(
            id = "txn-001",
            accountId = "account-123",
            type = "CREDIT",
            amountValue = BigDecimal("50.00"),
            amountCurrency = "BRL",
            status = "SUCCEEDED",
            timestamp = Instant.now(),
            createdAt = Instant.now()
        )
    }

    @Test
    fun `should save transaction`() {
        // Given
        whenever(transactionMongoRepository.save(any())).thenReturn(transactionDocument)

        // When
        val result = transactionRepositoryAdapter.save(transaction)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo("txn-001")
        assertThat(result.accountId).isEqualTo("account-123")

        verify(transactionMongoRepository).save(any())
    }

    @Test
    fun `should find transaction by id`() {
        // Given
        whenever(transactionMongoRepository.findById("txn-001")).thenReturn(Optional.of(transactionDocument))

        // When
        val result = transactionRepositoryAdapter.findById("txn-001")

        // Then
        assertThat(result).isNotNull()
        assertThat(result?.id).isEqualTo("txn-001")

        verify(transactionMongoRepository).findById("txn-001")
    }

    @Test
    fun `should return null when transaction not found`() {
        // Given
        whenever(transactionMongoRepository.findById("non-existent")).thenReturn(Optional.empty())

        // When
        val result = transactionRepositoryAdapter.findById("non-existent")

        // Then
        assertThat(result).isNull()

        verify(transactionMongoRepository).findById("non-existent")
    }
}