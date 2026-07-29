package com.itau.transaction.infrastructure.messaging.consumer

import com.itau.transaction.application.consumer.AccountCreatedConsumer
import com.itau.transaction.application.port.MetricsPort
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest

@Component
class SqsAccountCreatedListener(
    private val sqsClient: SqsClient,
    private val accountCreatedConsumer: AccountCreatedConsumer,
    private val metricsPort: MetricsPort
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Value("\${app.sqs.queue-url:http://localhost:4566/000000000000/conta-bancaria-criada}")
    private lateinit var queueUrl: String

    @Scheduled(fixedDelayString = "\${app.sqs.poll-interval:5000}")
    fun pollMessages() {
        try {
            val request = ReceiveMessageRequest.builder()
                .queueUrl(queueUrl)
                .maxNumberOfMessages(10)
                .waitTimeSeconds(5)
                .build()

            val messages = sqsClient.receiveMessage(request).messages()

            messages.forEach { message ->
                try {
                    accountCreatedConsumer.consume(message.body())
                    metricsPort.recordSqsMessageConsumed()
                    deleteMessage(message.receiptHandle())
                    logger.info("Successfully processed message {}", message.messageId())
                } catch (e: Exception) {
                    metricsPort.recordSqsMessageFailed()
                    logger.error("Failed to process message {}: {}", message.messageId(), e.message)
                }
            }
        } catch (e: Exception) {
            logger.error("Error polling SQS: {}", e.message)
        }
    }

    private fun deleteMessage(receiptHandle: String) {
        val deleteRequest = DeleteMessageRequest.builder()
            .queueUrl(queueUrl)
            .receiptHandle(receiptHandle)
            .build()
        sqsClient.deleteMessage(deleteRequest)
    }
}