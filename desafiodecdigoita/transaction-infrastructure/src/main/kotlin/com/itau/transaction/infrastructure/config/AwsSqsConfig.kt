package com.itau.transaction.infrastructure.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.sqs.SqsClient
import java.net.URI

@Configuration
class AwsSqsConfig {

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