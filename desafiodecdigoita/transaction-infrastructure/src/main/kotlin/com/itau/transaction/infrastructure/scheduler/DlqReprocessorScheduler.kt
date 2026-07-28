package com.itau.transaction.infrastructure.scheduler

import com.itau.transaction.infrastructure.messaging.reprocessor.DlqMessageReprocessor
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest

/**
 * Scheduled task that periodically reprocesses messages from the Dead Letter Queue (DLQ).
 *
 * Configuration:
 * - Interval: configurable via app.dlq.reprocessor.interval (default: PT5M = 5 minutes)
 * - Max batch: configurable via app.dlq.reprocessor.max-batch-size (default: 10)
 * - Circuit Breaker: wraps each reprocess call to prevent cascade failures
 *
 * Flow:
 * 1. Receive messages from DLQ (max batch per cycle)
 * 2. For each message, reprocess via DlqMessageReprocessor (with Circuit Breaker)
 * 3. If successful, delete message (ACK)
 * 4. If failed, message returns to DLQ with visibility timeout
 */
@Component
class DlqReprocessorScheduler(
    private val sqsClient: SqsClient,
    private val reprocessor: DlqMessageReprocessor,
    @Value("\${app.sqs.dlq-url}") private val dlqUrl: String,
    @Value("\${app.dlq.reprocessor.max-batch-size:10}") private val maxBatchSize: Int
) {

    private val log = LoggerFactory.getLogger(DlqReprocessorScheduler::class.java)

    @Scheduled(fixedDelayString = "\${app.dlq.reprocessor.interval:PT5M}")
    fun reprocessDlqMessages() {
        log.info("Starting DLQ reprocessing cycle")

        val messages = try {
            sqsClient.receiveMessage(
                ReceiveMessageRequest.builder()
                    .queueUrl(dlqUrl)
                    .maxNumberOfMessages(maxBatchSize)
                    .waitTimeSeconds(5)
                    .build()
            ).messages()
        } catch (e: Exception) {
            log.error("Failed to receive messages from DLQ: ${e.message}")
            return
        }

        if (messages.isEmpty()) {
            log.info("No messages found in DLQ. Waiting for next cycle.")
            return
        }

        log.info("Received ${messages.size} messages from DLQ")

        var successCount = 0
        var failCount = 0

        messages.forEach { message ->
            try {
                reprocessor.reprocess(message)
                deleteMessage(message)
                successCount++
                log.info("Successfully reprocessed DLQ message ${message.messageId()}")
            } catch (e: Exception) {
                failCount++
                log.warn("Failed to reprocess DLQ message ${message.messageId()}: ${e.message}")
                // Message returns to DLQ with visibility timeout
            }
        }

        log.info("DLQ reprocessing cycle completed: $successCount succeeded, $failCount failed")
    }

    private fun deleteMessage(message: software.amazon.awssdk.services.sqs.model.Message) {
        try {
            sqsClient.deleteMessage { builder ->
                builder.queueUrl(dlqUrl)
                    .receiptHandle(message.receiptHandle())
            }
        } catch (e: Exception) {
            log.warn("Failed to delete reprocessed message ${message.messageId()}: ${e.message}")
        }
    }
}