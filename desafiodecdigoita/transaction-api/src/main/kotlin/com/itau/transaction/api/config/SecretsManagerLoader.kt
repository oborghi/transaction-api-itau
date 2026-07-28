package com.itau.transaction.api.config

import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.boot.SpringApplication
import org.springframework.boot.env.EnvironmentPostProcessor
import org.springframework.core.env.ConfigurableEnvironment
import org.springframework.core.env.MapPropertySource
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

/**
 * Loads secrets from AWS Secrets Manager at startup and injects them as Spring properties.
 * Used in AWS deployment (ECS/EKS) where Vault is not available.
 *
 * AWS Secrets Manager path structure:
 *   transaction-api/mongodb → { "uri": "...", "username": "...", "password": "..." }
 *   transaction-api/jwt → { "secret": "...", "issuer": "..." }
 *   transaction-api/credentials → { "client_id": "...", "client_secret": "..." }
 */
class SecretsManagerLoader : EnvironmentPostProcessor {

    private val log = LoggerFactory.getLogger(SecretsManagerLoader::class.java)
    private val objectMapper = ObjectMapper()

    override fun postProcessEnvironment(environment: ConfigurableEnvironment, application: SpringApplication) {
        // Check if AWS Secrets Manager is enabled
        val secretsManagerEnabled = environment.getProperty("app.secrets.aws.enabled", "false")
        if (secretsManagerEnabled != "true") {
            log.info("AWS Secrets Manager integration disabled. Using Vault or default configuration.")
            return
        }

        val awsRegion = environment.getProperty("aws.region", "sa-east-1")
        val awsAccessKey = environment.getProperty("aws.access-key-id", "")
        val awsSecretKey = environment.getProperty("aws.secret-access-key", "")

        if (awsAccessKey.isBlank() || awsSecretKey.isBlank()) {
            log.warn("AWS credentials not configured. Skipping AWS Secrets Manager loading.")
            return
        }

        val secretsManagerClient = SecretsManagerClient.builder()
            .region(Region.of(awsRegion))
            .credentialsProvider(
                StaticCredentialsProvider.create(
                    AwsBasicCredentials.create(awsAccessKey, awsSecretKey)
                )
            )
            .build()

        val secrets = mutableMapOf<String, Any>()

        // Load MongoDB secrets
        loadSecret(secretsManagerClient, "transaction-api/mongodb")?.let { mongoProps ->
            mongoProps["uri"]?.let { secrets["spring.data.mongodb.uri"] = it }
            log.info("Loaded MongoDB secret from AWS Secrets Manager")
        }

        // Load JWT secrets
        loadSecret(secretsManagerClient, "transaction-api/jwt")?.let { jwtProps ->
            jwtProps["secret"]?.let { secrets["app.security.jwt.secret"] = it }
            jwtProps["issuer"]?.let { secrets["app.security.jwt.issuer"] = it }
            log.info("Loaded JWT secret from AWS Secrets Manager")
        }

        // Load API credentials
        loadSecret(secretsManagerClient, "transaction-api/credentials")?.let { credProps ->
            credProps["client_id"]?.let { secrets["app.security.client.id"] = it }
            credProps["client_secret"]?.let { secrets["app.security.client.secret"] = it }
            log.info("Loaded API credentials from AWS Secrets Manager")
        }

        // Load AWS/SQS secrets
        loadSecret(secretsManagerClient, "transaction-api/sqs")?.let { sqsProps ->
            sqsProps["endpoint"]?.let { secrets["aws.endpoint-url"] = it }
            sqsProps["region"]?.let { secrets["aws.region"] = it }
            sqsProps["access_key"]?.let { secrets["aws.access-key-id"] = it }
            sqsProps["secret_key"]?.let { secrets["aws.secret-access-key"] = it }
            log.info("Loaded AWS/SQS secrets from AWS Secrets Manager")
        }

        if (secrets.isNotEmpty()) {
            val propertySource = MapPropertySource("aws-secrets-manager", secrets)
            environment.propertySources.addFirst(propertySource)
            log.info("Successfully loaded ${secrets.size} properties from AWS Secrets Manager")
        }

        secretsManagerClient.close()
    }

    @Suppress("UNCHECKED_CAST")
    private fun loadSecret(client: SecretsManagerClient, secretName: String): Map<String, Any>? {
        return try {
            val request = GetSecretValueRequest.builder()
                .secretId(secretName)
                .build()

            val response = client.getSecretValue(request)
            val secretString = response.secretString()

            objectMapper.readValue(secretString, Map::class.java) as? Map<String, Any>
        } catch (e: Exception) {
            log.warn("Failed to load secret '$secretName' from AWS Secrets Manager: ${e.message}")
            null
        }
    }
}