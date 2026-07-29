package com.itau.transaction.infrastructure.scheduler

import com.itau.transaction.infrastructure.config.TransactionMetrics
import com.itau.transaction.infrastructure.messaging.reprocessor.DlqMessageReprocessor
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.*
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest
import software.amazon.awssdk.services.sqs.model.Message
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse
import java.util.function.Consumer

class DlqReprocessorSchedulerTest {

    private lateinit var sqsClient: SqsClient
    private lateinit var reprocessor: DlqMessageReprocessor
    private lateinit var transactionMetrics: TransactionMetrics
    private lateinit var scheduler: DlqReprocessorScheduler

    @BeforeEach
    fun setUp() {
        sqsClient = mock()
        reprocessor = mock()
        transactionMetrics = mock()
        scheduler = DlqReprocessorScheduler(
            sqsClient,
            reprocessor,
            transactionMetrics,
            "http://localhost:4566/000000000000/dlq",
            10
        )
    }

    @Test
    fun `reprocessDlqMessages should process messages successfully`() {
        val message = Message.builder()
            .messageId("msg-1")
            .body("""{"account":{"id":"acc-1","owner":"owner-1","status":"ENABLED"}}""")
            .receiptHandle("receipt-1")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message).build())

        scheduler.reprocessDlqMessages()

        verify(reprocessor).reprocess(message)
        verify(sqsClient).deleteMessage(any<Consumer<DeleteMessageRequest.Builder>>())
    }

    @Test
    fun `reprocessDlqMessages should handle empty DLQ`() {
        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(emptyList()).build())

        scheduler.reprocessDlqMessages()

        verify(reprocessor, never()).reprocess(any())
    }

    @Test
    fun `reprocessDlqMessages should handle SQS receive failure`() {
        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenThrow(RuntimeException("SQS unavailable"))

        scheduler.reprocessDlqMessages()

        verify(reprocessor, never()).reprocess(any())
    }

    @Test
    fun `reprocessDlqMessages should continue after reprocess failure`() {
        val msg1 = Message.builder().messageId("msg-1").body("{}").receiptHandle("r1").build()
        val msg2 = Message.builder().messageId("msg-2").body("{}").receiptHandle("r2").build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(msg1, msg2).build())
        whenever(reprocessor.reprocess(msg1)).thenThrow(RuntimeException("parse error"))

        scheduler.reprocessDlqMessages()

        verify(reprocessor).reprocess(msg1)
        verify(reprocessor).reprocess(msg2)
    }

    @Test
    fun `reprocessDlqMessages should handle delete message failure`() {
        val message = Message.builder()
            .messageId("msg-1")
            .body("""{"account":{"id":"acc-1","owner":"owner-1","status":"ENABLED"}}""")
            .receiptHandle("receipt-1")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message).build())
        whenever(reprocessor.reprocess(message)).then { }

        scheduler.reprocessDlqMessages()

        verify(reprocessor).reprocess(message)
    }

    @Test
    fun `reprocessDlqMessages should limit batch size`() {
        val messages = (1..15).map { i ->
            Message.builder()
                .messageId("msg-$i")
                .body("""{"account":{"id":"acc-$i","owner":"owner-$i","status":"ENABLED"}}""")
                .receiptHandle("receipt-$i")
                .build()
        }

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(messages).build())

        scheduler.reprocessDlqMessages()

        verify(reprocessor, times(15)).reprocess(any())
    }

    @Test
    fun `reprocessDlqMessages should not delete message on reprocess failure`() {
        val message = Message.builder()
            .messageId("msg-1")
            .body("{}")
            .receiptHandle("receipt-1")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message).build())
        whenever(reprocessor.reprocess(message)).thenThrow(RuntimeException("error"))

        scheduler.reprocessDlqMessages()

        verify(sqsClient, never()).deleteMessage(any<DeleteMessageRequest>())
    }
}