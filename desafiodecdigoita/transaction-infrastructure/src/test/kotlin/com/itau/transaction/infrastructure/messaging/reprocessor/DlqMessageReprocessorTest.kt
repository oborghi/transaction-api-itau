package com.itau.transaction.infrastructure.messaging.reprocessor

import com.itau.transaction.application.service.RegisterAccountUseCase
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.*
import software.amazon.awssdk.services.sqs.model.Message

class DlqMessageReprocessorTest {

    private lateinit var registerAccountUseCase: RegisterAccountUseCase
    private lateinit var circuitBreakerRegistry: CircuitBreakerRegistry
    private lateinit var reprocessor: DlqMessageReprocessor

    @BeforeEach
    fun setUp() {
        registerAccountUseCase = mock()
        circuitBreakerRegistry = CircuitBreakerRegistry.ofDefaults()
        reprocessor = DlqMessageReprocessor(registerAccountUseCase, circuitBreakerRegistry)
    }

    @Test
    fun `reprocess should parse message and register account`() {
        val json = """{"account":{"id":"acc-1","owner":"owner-1","status":"ENABLED"}}"""
        val message = Message.builder()
            .messageId("msg-1")
            .body(json)
            .receiptHandle("receipt-1")
            .build()

        reprocessor.reprocess(message)

        verify(registerAccountUseCase).execute("acc-1", "owner-1", "ENABLED")
    }

    @Test
    fun `reprocess should propagate exception from use case`() {
        val json = """{"account":{"id":"acc-1","owner":"owner-1","status":"ENABLED"}}"""
        val message = Message.builder()
            .messageId("msg-1")
            .body(json)
            .receiptHandle("receipt-1")
            .build()

        whenever(registerAccountUseCase.execute(any(), any(), any()))
            .thenThrow(RuntimeException("DB error"))

        assertThrows(RuntimeException::class.java) {
            reprocessor.reprocess(message)
        }
    }

    @Test
    fun `reprocess should handle different account statuses`() {
        val json = """{"account":{"id":"acc-2","owner":"owner-2","status":"DISABLED"}}"""
        val message = Message.builder()
            .messageId("msg-2")
            .body(json)
            .receiptHandle("receipt-2")
            .build()

        reprocessor.reprocess(message)

        verify(registerAccountUseCase).execute("acc-2", "owner-2", "DISABLED")
    }
}