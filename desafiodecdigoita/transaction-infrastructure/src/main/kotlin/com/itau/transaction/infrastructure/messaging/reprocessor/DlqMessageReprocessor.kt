package com.itau.transaction.infrastructure.messaging.reprocessor

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.itau.transaction.application.service.RegisterAccountUseCase
import io.github.resilience4j.circuitbreaker.CircuitBreaker
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.sqs.model.Message

/**
 * Reprocesses messages from the Dead Letter Queue (DLQ).
 * Applies Circuit Breaker pattern to prevent cascade failures.
 *
 * Rules:
 * - Idempotent: if account already exists, message is discarded
 * - Circuit Breaker: if 50%+ calls fail, CB opens and waits before retrying
 * - Max batch: 10 messages per cycle to avoid overload
 */
@Component
class DlqMessageReprocessor(
    private val registerAccountUseCase: RegisterAccountUseCase,
    private val circuitBreakerRegistry: CircuitBreakerRegistry
) {

    private val log = LoggerFactory.getLogger(DlqMessageReprocessor::class.java)
    private val objectMapper = ObjectMapper()

    private val circuitBreaker: CircuitBreaker =
        circuitBreakerRegistry.circuitBreaker("dlqReprocessorCircuitBreaker")

    fun reprocess(message: Message) {
        CircuitBreaker.decorateCallable(circuitBreaker) {
            val (accountId, owner, status) = parseMessage(message.body())
            registerAccountUseCase.execute(accountId, owner, status)
            log.debug("Successfully reprocessed DLQ message ${message.messageId()}")
        }.call()
    }

    private fun parseMessage(body: String): Triple<String, String, String> {
        val root: JsonNode = objectMapper.readTree(body)
        val accountNode = root.path("account")
        val accountId = accountNode.path("id").asText()
        val owner = accountNode.path("owner").asText()
        val status = accountNode.path("status").asText()
        return Triple(accountId, owner, status)
    }
}