package com.itau.transaction.infrastructure.messaging.producer

import com.itau.transaction.domain.port.EventPublisherPort
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.SendMessageRequest

@Component
class SqsEventPublisher(
    private val sqsClient: SqsClient,
    private val objectMapper: ObjectMapper
) : EventPublisherPort {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Value("\${app.sqs.queue-url:http://localhost:4566/000000000000/conta-bancaria-criada}")
    private lateinit var queueUrl: String

    override fun publish(event: Any) {
        try {
            val messageBody = objectMapper.writeValueAsString(event)
            val request = SendMessageRequest.builder()
                .queueUrl(queueUrl)
                .messageBody(messageBody)
                .build()

            sqsClient.sendMessage(request)
            logger.info("Published event to SQS: {}", event::class.simpleName)
        } catch (e: Exception) {
            logger.error("Failed to publish event to SQS: {}", e.message)
            throw e
        }
    }
}