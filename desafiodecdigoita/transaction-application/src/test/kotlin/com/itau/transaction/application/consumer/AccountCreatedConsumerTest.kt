package com.itau.transaction.application.consumer

import com.itau.transaction.application.service.RegisterAccountUseCase
import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import com.fasterxml.jackson.databind.ObjectMapper
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import java.math.BigDecimal
import java.time.Instant

@ExtendWith(MockitoExtension::class)
class AccountCreatedConsumerTest {

    @Mock
    private lateinit var registerAccountUseCase: RegisterAccountUseCase

    @Mock
    private lateinit var objectMapper: ObjectMapper

    @InjectMocks
    private lateinit var accountCreatedConsumer: AccountCreatedConsumer

    @Test
    fun `should process account created message successfully`() {
        // Given
        val message = """{"account":{"id":"account-001","owner":"owner-001","created_at":"1234567890","status":"ENABLED"}}"""

        val accountMessage = AccountMessage(
            account = AccountPayload(
                id = "account-001",
                owner = "owner-001",
                created_at = 1234567890L,
                status = "ENABLED"
            )
        )

        whenever(objectMapper.readValue(message, AccountMessage::class.java)).thenReturn(accountMessage)

        // When
        accountCreatedConsumer.consume(message)

        // Then
        verify(registerAccountUseCase).execute("account-001", "owner-001", "ENABLED")
    }

    @Test
    fun `should handle existing account gracefully`() {
        // Given
        val message = """{"account":{"id":"account-002","owner":"owner-002","created_at":"1234567890","status":"ENABLED"}}"""

        val accountMessage = AccountMessage(
            account = AccountPayload(
                id = "account-002",
                owner = "owner-002",
                created_at = 1234567890L,
                status = "ENABLED"
            )
        )

        whenever(objectMapper.readValue(message, AccountMessage::class.java)).thenReturn(accountMessage)

        // When
        accountCreatedConsumer.consume(message)

        // Then
        verify(registerAccountUseCase).execute("account-002", "owner-002", "ENABLED")
    }

    @Test
    fun `should handle DISABLED account status`() {
        // Given
        val message = """{"account":{"id":"account-003","owner":"owner-003","created_at":"1234567890","status":"DISABLED"}}"""

        val accountMessage = AccountMessage(
            account = AccountPayload(
                id = "account-003",
                owner = "owner-003",
                created_at = 1234567890L,
                status = "DISABLED"
            )
        )

        whenever(objectMapper.readValue(message, AccountMessage::class.java)).thenReturn(accountMessage)

        // When
        accountCreatedConsumer.consume(message)

        // Then
        verify(registerAccountUseCase).execute("account-003", "owner-003", "DISABLED")
    }
}