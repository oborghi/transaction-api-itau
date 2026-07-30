package com.itau.transaction.infrastructure.config

import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.AppenderBase
import org.slf4j.LoggerFactory
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import java.io.ByteArrayInputStream
import java.net.URI
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * Logback appender that uploads log files to S3.
 * Works with LocalStack (local) and real AWS S3.
 *
 * Configuration via environment variables:
 * - AWS_ENDPOINT_URL: S3 endpoint (LocalStack or AWS)
 * - AWS_DEFAULT_REGION: AWS region
 * - AWS_ACCESS_KEY_ID: AWS access key
 * - AWS_SECRET_ACCESS_KEY: AWS secret key
 * - S3_LOG_BUCKET: S3 bucket name (default: transaction-api-logs)
 */
class S3LogAppender : AppenderBase<ILoggingEvent>() {

    private val log = LoggerFactory.getLogger(S3LogAppender::class.java)
    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val timestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")

    private var s3Client: S3Client? = null
    private var bucketName: String = "transaction-api_logs"
    private var serviceName: String = "transaction-api"
    private var environment: String = "local"

    private val logBuffer = StringBuilder()
    private var currentDate: LocalDate = LocalDate.now()
    private var flushCounter = 0
    private val flushInterval = 50 // flush a cada 50 eventos

    override fun start() {
        bucketName = System.getenv("S3_LOG_BUCKET") ?: "transaction-api_logs"
        serviceName = System.getenv("SERVICE_NAME") ?: "transaction-api"
        environment = System.getenv("ENVIRONMENT") ?: "local"

        val endpointUrl = System.getenv("AWS_ENDPOINT_URL") ?: ""
        val region = System.getenv("AWS_DEFAULT_REGION") ?: "sa-east-1"
        val accessKey = System.getenv("AWS_ACCESS_KEY_ID") ?: "test"
        val secretKey = System.getenv("AWS_SECRET_ACCESS_KEY") ?: "test"

        try {
            val builder = S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(
                    StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)
                    )
                )

            if (endpointUrl.isNotBlank()) {
                builder.endpointOverride(URI.create(endpointUrl))
                builder.forcePathStyle(true) // necessário para LocalStack
            }

            s3Client = builder.build()
            log.info("S3LogAppender initialized. Bucket: $bucketName, Endpoint: ${endpointUrl.ifBlank { "AWS" }}")
            super.start()
        } catch (e: Exception) {
            log.warn("Failed to initialize S3 client. Logs will not be sent to S3: ${e.message}")
            // Não falha o startup, apenas desabilita o appender
        }
    }

    override fun append(eventObject: ILoggingEvent) {
        if (!isStarted || s3Client == null) return

        val now = LocalDate.now()
        if (now != currentDate) {
            // Novo dia, faz flush do buffer anterior
            flushBuffer()
            currentDate = now
        }

        val formattedMessage = formatEvent(eventObject)
        logBuffer.append(formattedMessage).append("\n")
        flushCounter++

        if (flushCounter >= flushInterval) {
            flushBuffer()
        }
    }

    private fun formatEvent(event: ILoggingEvent): String {
        val timestamp = java.time.LocalDateTime.now().format(timestampFormatter)
        val thread = event.threadName
        val level = event.level.toString()
        val logger = event.loggerName
        val message = event.formattedMessage
        val mdc = event.mdcPropertyMap

        val mdcStr = if (mdc.isNotEmpty()) {
            " " + mdc.entries.joinToString(" ") { (k, v) -> "$k=$v" }
        } else ""

        return "$timestamp [$thread] $level $logger - $message$mdcStr"
    }

    override fun stop() {
        flushBuffer()
        try {
            s3Client?.close()
        } catch (e: Exception) {
            log.warn("Error closing S3 client: ${e.message}")
        }
        super.stop()
    }

    private fun flushBuffer() {
        if (logBuffer.isEmpty() || s3Client == null) return

        try {
            val content = logBuffer.toString()
            val key = "$environment/$serviceName/${currentDate.format(dateFormatter)}/${serviceName}-${System.currentTimeMillis()}.log"

            val request = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(key)
                .contentType("text/plain")
                .build()

            s3Client!!.putObject(request, software.amazon.awssdk.core.sync.RequestBody.fromBytes(content.toByteArray()))
            logBuffer.clear()
            flushCounter = 0
        } catch (e: Exception) {
            log.warn("Failed to upload logs to S3: ${e.message}")
        }
    }
}