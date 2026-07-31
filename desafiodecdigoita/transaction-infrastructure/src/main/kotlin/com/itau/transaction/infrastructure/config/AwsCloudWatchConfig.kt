package com.itau.transaction.infrastructure.config

import io.micrometer.cloudwatch2.CloudWatchConfig
import io.micrometer.cloudwatch2.CloudWatchMeterRegistry
import io.micrometer.core.instrument.Clock
import io.micrometer.core.instrument.Metrics
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient
import java.net.URI
import java.time.Duration

/**
 * Provides the CloudWatchAsyncClient bean and wires the CloudWatchMeterRegistry
 * into the Spring CompositeMeterRegistry.
 *
 * NOTE: Spring Boot 3.3.x no longer ships the CloudWatch metrics export
 * auto-configuration (CloudWatchMetricsExportAutoConfiguration) inside
 * spring-boot-actuator-autoconfigure. So we create the CloudWatchMeterRegistry
 * manually and register it on the CompositeMeterRegistry.
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

    @Value("\${management.metrics.export.cloudwatch.namespace:TransactionAPI}")
    private lateinit var cloudWatchNamespace: String

    @Value("\${management.metrics.export.cloudwatch.step:30s}")
    private lateinit var cloudWatchStep: Duration

    @Value("\${management.metrics.export.cloudwatch.batch-size:20}")
    private var cloudWatchBatchSize: Int = 20

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

    @Bean
    fun cloudWatchMeterRegistry(cloudWatchAsyncClient: CloudWatchAsyncClient): CloudWatchMeterRegistry {
        val namespace = cloudWatchNamespace.ifBlank { "TransactionAPI" }
        log.info("Creating CloudWatchMeterRegistry with namespace: {}, step: {}, batchSize: {}",
            namespace, cloudWatchStep, cloudWatchBatchSize)

        val config = object : CloudWatchConfig {
            override fun get(key: String): String? = null
            override fun namespace(): String = namespace
            override fun step(): Duration = cloudWatchStep
            override fun batchSize(): Int = cloudWatchBatchSize
            override fun enabled(): Boolean = true
        }

        return CloudWatchMeterRegistry(config, Clock.SYSTEM, cloudWatchAsyncClient)
    }

    /**
     * Registers the CloudWatchMeterRegistry on the Micrometer global CompositeMeterRegistry.
     * Uses Metrics.globalRegistry (a static CompositeMeterRegistry) to avoid ordering
     * issues with Spring Boot Actuator's autoconfiguration.
     * The Spring Boot Actuator CompositeMeterRegistry delegates to this global registry.
     */
    @Bean
    fun cloudWatchMeterRegistryRegistrar(
        cloudWatchMeterRegistry: CloudWatchMeterRegistry
    ): Any {
        Metrics.globalRegistry.add(cloudWatchMeterRegistry)
        log.info("CloudWatchMeterRegistry added to Metrics.globalRegistry")
        return cloudWatchMeterRegistry
    }
}