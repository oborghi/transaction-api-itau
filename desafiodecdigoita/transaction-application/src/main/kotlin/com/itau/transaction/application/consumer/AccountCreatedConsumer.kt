package com.itau.transaction.application.consumer

import com.itau.transaction.application.service.RegisterAccountUseCase
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class AccountCreatedConsumer(
    private val registerAccountUseCase: RegisterAccountUseCase,
    private val objectMapper: ObjectMapper
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun consume(messageBody: String) {
        logger.info("Consuming account created message")

        try {
            val message = objectMapper.readValue(messageBody, AccountMessage::class.java)
            val account = message.account

            registerAccountUseCase.execute(
                accountId = account.id,
                owner = account.owner,
                status = account.status
            )

            logger.info("Successfully consumed account created message for account {}", account.id)
        } catch (e: Exception) {
            logger.error("Failed to consume account created message: ${e.message}", e)
            throw e
        }
    }
}

data class AccountMessage(
    val account: AccountPayload
)

data class AccountPayload(
    val id: String,
    val owner: String,
    val created_at: Long,
    val status: String
)