package com.itau.transaction.infrastructure.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.sqs.SqsClient
import java.net.URI

@Configuration
class AwsSqsConfig {

    private val log = LoggerFactory.getLogger(javaClass)

    @Value("\${aws.endpoint-url:http://localhost:4566}")
    private lateinit var endpointUrl: String

    @Value("\${aws.region:sa-east-1}")
    private lateinit var region: String

    @Value("\${aws.access-key-id:test}")
    private lateinit var accessKeyId: String

    @Value("\${aws.secret-access-key:test}")
    private lateinit var secretAccessKey: String

    @Bean
    fun sqsClient(): SqsClient {
        if (endpointUrl.isBlank()) {
            log.warn("AWS endpoint URL is blank, creating SQS client with default endpoint")
            val credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKeyId, secretAccessKey)
            )
            return SqsClient.builder()
                .credentialsProvider(credentials)
                .region(Region.of(region))
                .build()
        }
        log.info("Creating SQS client with endpoint: {}", endpointUrl)
        val credentials = StaticCredentialsProvider.create(
            AwsBasicCredentials.create(accessKeyId, secretAccessKey)
        )

        return SqsClient.builder()
            .endpointOverride(URI.create(endpointUrl))
            .credentialsProvider(credentials)
            .region(Region.of(region))
            .build()
    }
}
