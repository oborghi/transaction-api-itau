package com.itau.transaction.infrastructure.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.sqs.SqsClient
import java.net.URI

@Configuration
class AwsSqsConfig {

    private val log = LoggerFactory.getLogger(javaClass)

    @Value("\${aws.endpoint-url:}")
    private lateinit var endpointUrl: String

    @Value("\${aws.region:sa-east-1}")
    private lateinit var region: String

    @Value("\${aws.access-key-id:}")
    private lateinit var accessKeyId: String

    @Value("\${aws.secret-access-key:}")
    private lateinit var secretAccessKey: String

    @Bean
    fun sqsClient(): SqsClient {
        val regionObj = Region.of(region.ifBlank { "sa-east-1" })

        // Se endpoint URL está configurado (LocalStack), usa StaticCredentialsProvider
        if (!endpointUrl.isNullOrBlank()) {
            log.info("Creating SQS client with endpoint: {}, region: {}", endpointUrl, regionObj)
            val credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(
                    accessKeyId.ifBlank { "test" },
                    secretAccessKey.ifBlank { "test" }
                )
            )
            return SqsClient.builder()
                .endpointOverride(URI.create(endpointUrl))
                .credentialsProvider(credentials)
                .region(regionObj)
                .build()
        }

        // Se credenciais explícitas foram fornecidas, usa StaticCredentialsProvider
        if (!accessKeyId.isNullOrBlank() && !secretAccessKey.isNullOrBlank()) {
            log.info("Creating SQS client with StaticCredentialsProvider, region: {}", regionObj)
            val credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKeyId, secretAccessKey)
            )
            val builder = SqsClient.builder()
                .credentialsProvider(credentials)
                .region(regionObj)
            return builder.build()
        }

        // Caso contrário, usa DefaultCredentialsProvider (IAM role em ECS, etc.)
        log.info("Creating SQS client with DefaultCredentialsProviderChain, region: {}", regionObj)
        return SqsClient.builder()
            .region(regionObj)
            .build()
    }
}
