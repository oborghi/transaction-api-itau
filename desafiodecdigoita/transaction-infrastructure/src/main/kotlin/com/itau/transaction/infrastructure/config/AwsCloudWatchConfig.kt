package com.itau.transaction.infrastructure.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient
import java.net.URI

/**
 * Provides the CloudWatchAsyncClient bean.
 * Spring Boot's auto-configuration (CloudWatchMetricsExportAutoConfiguration)
 * will create the CloudWatchMeterRegistry and bind it to the CompositeMeterRegistry
 * when management.metrics.export.cloudwatch.enabled=true.
 *
 * This avoids creating a separate manual CloudWatchMeterRegistry that might not
 * correctly integrate with the CompositeMeterRegistry used by TransactionMetrics.
 */
@Configuration
@ConditionalOnProperty(name = ["CLOUDWATCH_ENABLED"], havingValue = "true", matchIfMissing = false)
class AwsCloudWatchConfig {

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
    fun cloudWatchAsyncClient(): CloudWatchAsyncClient {
        val regionObj = Region.of(region.ifBlank { "sa-east-1" })
        log.info("Creating CloudWatchAsyncClient with region: {}", regionObj)

        if (!endpointUrl.isNullOrBlank()) {
            log.info("CloudWatchAsyncClient using endpoint: {}", endpointUrl)
            val credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(
                    accessKeyId.ifBlank { "test" },
                    secretAccessKey.ifBlank { "test" }
                )
            )
            return CloudWatchAsyncClient.builder()
                .endpointOverride(URI.create(endpointUrl))
                .credentialsProvider(credentials)
                .region(regionObj)
                .build()
        }

        if (!accessKeyId.isNullOrBlank() && !secretAccessKey.isNullOrBlank()) {
            log.info("CloudWatchAsyncClient using StaticCredentialsProvider")
            val credentials = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKeyId, secretAccessKey)
            )
            return CloudWatchAsyncClient.builder()
                .credentialsProvider(credentials)
                .region(regionObj)
                .build()
        }

        log.info("CloudWatchAsyncClient using DefaultCredentialsProviderChain (IAM role)")
        return CloudWatchAsyncClient.builder()
            .region(regionObj)
            .build()
    }
}
