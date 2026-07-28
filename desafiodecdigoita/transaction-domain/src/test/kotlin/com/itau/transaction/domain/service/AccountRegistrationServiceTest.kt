package com.itau.transaction.domain.service

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.port.AccountRepositoryPort
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.mockito.kotlin.doAnswer
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class AccountRegistrationServiceTest {

    @Mock
    private lateinit var accountRepository: AccountRepositoryPort

    @InjectMocks
    private lateinit var accountRegistrationService: AccountRegistrationService

    @Test
    fun `should register new account successfully`() {
        // Given
        val accountId = "account-001"
        val owner = "owner-001"
        val status = "ENABLED"

        whenever(accountRepository.existsById(accountId)).thenReturn(false)
        doAnswer { it.arguments[0] }.`when`(accountRepository).save(any())

        // When
        val result = accountRegistrationService.register(accountId, owner, status)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(accountId)
        assertThat(result.owner).isEqualTo(owner)
        assertThat(result.balance.amount).isEqualByComparingTo(BigDecimal("0.00"))
        assertThat(result.status).isEqualTo(AccountStatus.ENABLED)
        assertThat(result.version).isEqualTo(0)

        verify(accountRepository).existsById(accountId)
        verify(accountRepository).save(any())
    }

    @Test
    fun `should skip registration when account already exists`() {
        // Given
        val accountId = "account-002"
        val existingAccount = Account(
            id = accountId,
            owner = "existing-owner",
            balance = Money(amount = BigDecimal("50.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 1
        )

        whenever(accountRepository.existsById(accountId)).thenReturn(true)
        whenever(accountRepository.findById(accountId)).thenReturn(Optional.of(existingAccount))

        // When
        val result = accountRegistrationService.register(accountId, "new-owner", "ENABLED")

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(accountId)
        assertThat(result.owner).isEqualTo("existing-owner")
        assertThat(result.balance.amount).isEqualByComparingTo(BigDecimal("50.00"))

        verify(accountRepository).existsById(accountId)
        verify(accountRepository).findById(accountId)
        verify(accountRepository, never()).save(any())
    }

    @Test
    fun `should register account with DISABLED status`() {
        // Given
        val accountId = "account-003"
        val owner = "owner-003"

        whenever(accountRepository.existsById(accountId)).thenReturn(false)
        doAnswer { it.arguments[0] }.`when`(accountRepository).save(any())

        // When
        val result = accountRegistrationService.register(accountId, owner, "DISABLED")

        // Then
        assertThat(result).isNotNull()
        assertThat(result.status).isEqualTo(AccountStatus.DISABLED)

        verify(accountRepository).save(any())
    }

    @Test
    fun `should initialize account with zero balance`() {
        // Given
        val accountId = "account-004"
        val owner = "owner-004"

        whenever(accountRepository.existsById(accountId)).thenReturn(false)
        doAnswer { it.arguments[0] }.`when`(accountRepository).save(any())

        // When
        val result = accountRegistrationService.register(accountId, owner, "ENABLED")

        // Then
        assertThat(result.balance.amount).isEqualByComparingTo(BigDecimal("0.00"))
        assertThat(result.balance.currency).isEqualTo("BRL")
    }
}