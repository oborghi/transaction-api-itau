package com.itau.transaction.infrastructure.messaging.producer

import com.fasterxml.jackson.databind.ObjectMapper
import com.itau.transaction.infrastructure.config.JacksonConfig
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import software.amazon.awssdk.core.SdkBytes
import software.amazon.awssdk.services.sqs.SqsClient
import software.amazon.awssdk.services.sqs.model.SendMessageRequest

@ExtendWith(MockitoExtension::class)
class SqsEventPublisherTest {

    @Mock
    private lateinit var sqsClient: SqsClient

    @Mock
    private lateinit var objectMapper: ObjectMapper

    @InjectMocks
    private lateinit var sqsEventPublisher: SqsEventPublisher

    private val queueUrl = "http://localhost:4566/000000000000/conta-bancaria-criada"

    @BeforeEach
    fun setUp() {
        // Set the queueUrl via reflection since it's injected via @Value
        val queueUrlField = SqsEventPublisher::class.java.getDeclaredField("queueUrl")
        queueUrlField.isAccessible = true
        queueUrlField.set(sqsEventPublisher, queueUrl)
    }

    @Test
    fun `should publish event to SQS`() {
        // Given
        val event = mapOf("key" to "value")
        val eventJson = """{"key":"value"}"""
        
        `when`(objectMapper.writeValueAsString(event)).thenReturn(eventJson)

        // When
        sqsEventPublisher.publish(event)

        // Then
        verify(objectMapper).writeValueAsString(event)
        verify(sqsClient).sendMessage(any(SendMessageRequest::class.java))
    }

    @Test
    fun `should publish string event to SQS`() {
        // Given
        val event = "test-event"
        val eventJson = "\"test-event\""

        `when`(objectMapper.writeValueAsString(event)).thenReturn(eventJson)

        // When
        sqsEventPublisher.publish(event)

        // Then
        verify(objectMapper).writeValueAsString(event)
        verify(sqsClient).sendMessage(any(SendMessageRequest::class.java))
    }
}