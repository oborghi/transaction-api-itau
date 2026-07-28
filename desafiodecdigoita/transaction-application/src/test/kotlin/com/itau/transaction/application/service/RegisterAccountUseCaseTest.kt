package com.itau.transaction.application.service

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.service.AccountRegistrationService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.time.Instant
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class RegisterAccountUseCaseTest {

    @Mock
    private lateinit var accountRegistrationService: AccountRegistrationService

    @Mock
    private lateinit var accountRepository: AccountRepositoryPort

    @InjectMocks
    private lateinit var registerAccountUseCase: RegisterAccountUseCase

    @Test
    fun `should register new account successfully`() {
        // Given
        val accountId = "account-001"
        val owner = "owner-001"
        val status = "ENABLED"

        val account = Account(
            id = accountId,
            owner = owner,
            balance = Money(amount = BigDecimal("0.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )

        `when`(accountRegistrationService.register(accountId, owner, status)).thenReturn(account)

        // When
        val result = registerAccountUseCase.execute(accountId, owner, status)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(accountId)
        assertThat(result.owner).isEqualTo(owner)
        assertThat(result.status).isEqualTo(AccountStatus.ENABLED)
        assertThat(result.balance.amount).isEqualByComparingTo(BigDecimal("0.00"))

        verify(accountRegistrationService).register(accountId, owner, status)
    }

    @Test
    fun `should return existing account when account already exists`() {
        // Given
        val accountId = "account-002"
        val owner = "owner-002"
        val status = "ENABLED"

        val existingAccount = Account(
            id = accountId,
            owner = "existing-owner",
            balance = Money(amount = BigDecimal("50.00"), currency = "BRL"),
            status = AccountStatus.ENABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 1
        )

        `when`(accountRegistrationService.register(accountId, owner, status)).thenReturn(existingAccount)

        // When
        val result = registerAccountUseCase.execute(accountId, owner, status)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.id).isEqualTo(accountId)
        assertThat(result.owner).isEqualTo("existing-owner")
        assertThat(result.balance.amount).isEqualByComparingTo(BigDecimal("50.00"))

        verify(accountRegistrationService).register(accountId, owner, status)
    }

    @Test
    fun `should register account with DISABLED status`() {
        // Given
        val accountId = "account-003"
        val owner = "owner-003"
        val status = "DISABLED"

        val account = Account(
            id = accountId,
            owner = owner,
            balance = Money(amount = BigDecimal("0.00"), currency = "BRL"),
            status = AccountStatus.DISABLED,
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )

        `when`(accountRegistrationService.register(accountId, owner, status)).thenReturn(account)

        // When
        val result = registerAccountUseCase.execute(accountId, owner, status)

        // Then
        assertThat(result).isNotNull()
        assertThat(result.status).isEqualTo(AccountStatus.DISABLED)

        verify(accountRegistrationService).register(accountId, owner, status)
    }
}