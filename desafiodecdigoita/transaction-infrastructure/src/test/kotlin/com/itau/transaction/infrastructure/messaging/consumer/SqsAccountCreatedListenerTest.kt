package com.itau.transaction.infrastructure.messaging.consumer

import com.itau.transaction.application.consumer.AccountCreatedConsumer
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.doNothing
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest
import software.amazon.awssdk.services.sqs.model.DeleteMessageResponse
import software.amazon.awssdk.services.sqs.model.Message
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse

@ExtendWith(MockitoExtension::class)
class SqsAccountCreatedListenerTest {

    @Mock
    private lateinit var sqsClient: SqsClient

    @Mock
    private lateinit var accountCreatedConsumer: AccountCreatedConsumer

    private lateinit var listener: SqsAccountCreatedListener

    @BeforeEach
    fun setUp() {
        listener = SqsAccountCreatedListener(sqsClient, accountCreatedConsumer)
        // Set queueUrl via reflection since it's @Value injected
        val field = SqsAccountCreatedListener::class.java.getDeclaredField("queueUrl")
        field.isAccessible = true
        field.set(listener, "http://localhost:4566/000000000000/conta-bancaria-criada")
    }

    @Test
    fun `should poll and process messages successfully`() {
        val message = Message.builder()
            .messageId("msg-1")
            .receiptHandle("receipt-1")
            .body("""{"account":{"id":"acc-1","owner":"owner-1"}}""")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message).build())
        whenever(sqsClient.deleteMessage(any<DeleteMessageRequest>()))
            .thenReturn(DeleteMessageResponse.builder().build())
        doNothing().whenever(accountCreatedConsumer).consume(any())

        listener.pollMessages()

        verify(accountCreatedConsumer).consume(message.body())
        verify(sqsClient).deleteMessage(any<DeleteMessageRequest>())
    }

    @Test
    fun `should handle empty message list`() {
        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(emptyList()).build())

        listener.pollMessages()

        verify(accountCreatedConsumer, never()).consume(any())
        verify(sqsClient, never()).deleteMessage(any<DeleteMessageRequest>())
    }

    @Test
    fun `should handle consumer exception without deleting message`() {
        val message = Message.builder()
            .messageId("msg-2")
            .receiptHandle("receipt-2")
            .body("""{"invalid":"json"}""")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message).build())
        doThrow(RuntimeException("Parse error")).whenever(accountCreatedConsumer).consume(any())

        listener.pollMessages()

        verify(accountCreatedConsumer).consume(message.body())
        verify(sqsClient, never()).deleteMessage(any<DeleteMessageRequest>())
    }

    @Test
    fun `should handle SQS client exception`() {
        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenThrow(RuntimeException("SQS unavailable"))

        listener.pollMessages()

        verify(accountCreatedConsumer, never()).consume(any())
    }

    @Test
    fun `should process multiple messages`() {
        val message1 = Message.builder()
            .messageId("msg-1")
            .receiptHandle("receipt-1")
            .body("""{"account":{"id":"acc-1"}}""")
            .build()
        val message2 = Message.builder()
            .messageId("msg-2")
            .receiptHandle("receipt-2")
            .body("""{"account":{"id":"acc-2"}}""")
            .build()

        whenever(sqsClient.receiveMessage(any<ReceiveMessageRequest>()))
            .thenReturn(ReceiveMessageResponse.builder().messages(message1, message2).build())
        whenever(sqsClient.deleteMessage(any<DeleteMessageRequest>()))
            .thenReturn(DeleteMessageResponse.builder().build())
        doNothing().whenever(accountCreatedConsumer).consume(any())

        listener.pollMessages()

        verify(accountCreatedConsumer).consume(message1.body())
        verify(accountCreatedConsumer).consume(message2.body())
    }
}