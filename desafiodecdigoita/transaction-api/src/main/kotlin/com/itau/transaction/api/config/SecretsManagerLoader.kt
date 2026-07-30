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
 * Loads secrets from AWS Secrets Manager at startup and injects them as system properties.
 * Only sets properties that are NOT already defined as environment variables.
 */
class SecretsManagerLoader : EnvironmentPostProcessor {

    private val log = LoggerFactory.getLogger(SecretsManagerLoader::class.java)
    private val objectMapper = ObjectMapper()

    override fun postProcessEnvironment(environment: ConfigurableEnvironment, application: SpringApplication) {
        val secretsManagerEnabled = environment.getProperty("app.secrets.aws.enabled", "false")
        if (secretsManagerEnabled != "true") {
            log.info("AWS Secrets Manager integration disabled.")
            return
        }

        val awsRegion = environment.getProperty("aws.region", "sa-east-1")
        val awsAccessKey = environment.getProperty("aws.access-key-id", "")
        val awsSecretKey = environment.getProperty("aws.secret-access-key", "")

        if (awsAccessKey.isBlank() || awsSecretKey.isBlank()) {
            log.warn("AWS credentials not configured. Skipping AWS Secrets Manager loading.")
            return
        }

        val awsEndpointUrl = environment.getProperty("aws.endpoint-url", "")

        val secretsManagerClientBuilder = SecretsManagerClient.builder()
            .region(Region.of(awsRegion))
            .credentialsProvider(
                StaticCredentialsProvider.create(
                    AwsBasicCredentials.create(awsAccessKey, awsSecretKey)
                )
            )

        if (awsEndpointUrl.isNotBlank()) {
            secretsManagerClientBuilder.endpointOverride(java.net.URI.create(awsEndpointUrl))
            log.info("Using custom AWS endpoint: $awsEndpointUrl")
        }

        val secretsManagerClient = secretsManagerClientBuilder.build()
        val secrets = mutableMapOf<String, Any>()

        fun Any?.asString(): String? = this?.toString()

        fun setIfAbsent(key: String, value: String) {
            // Verifica se já existe variável de ambiente para esta propriedade
            val envKey = key.replace(".", "_").replace("-", "_").uppercase()
            if (System.getenv(envKey) != null) {
                log.info("Skipping '$key' (set via env var \$$envKey)")
                return
            }
            // Verifica se já foi setada como system property
            if (System.getProperty(key) != null) {
                log.info("Skipping '$key' (already set as system property)")
                return
            }
            // Seta como system property e também no map do environment
            System.setProperty(key, value)
            secrets[key] = value
            log.info("Set property '$key' from Secrets Manager")
        }

        // Load MongoDB secrets
        loadSecret(secretsManagerClient, "transaction-api/mongodb")?.let { mongoProps ->
            mongoProps["uri"]?.asString()?.let { setIfAbsent("spring.data.mongodb.uri", it) }
        }

        // Load JWT secrets
        loadSecret(secretsManagerClient, "transaction-api/jwt")?.let { jwtProps ->
            jwtProps["secret"]?.asString()?.let { setIfAbsent("app.security.jwt.secret", it) }
            jwtProps["issuer"]?.asString()?.let { setIfAbsent("app.security.jwt.issuer", it) }
        }

        // Load API credentials
        loadSecret(secretsManagerClient, "transaction-api/credentials")?.let { credProps ->
            credProps["client_id"]?.asString()?.let { setIfAbsent("app.security.client.id", it) }
            credProps["client_secret"]?.asString()?.let { setIfAbsent("app.security.client.secret", it) }
        }

        // Load AWS/SQS secrets
        loadSecret(secretsManagerClient, "transaction-api/sqs")?.let { sqsProps ->
            sqsProps["endpoint"]?.asString()?.let { setIfAbsent("aws.endpoint-url", it) }
            sqsProps["region"]?.asString()?.let { setIfAbsent("aws.region", it) }
        }

        if (secrets.isNotEmpty()) {
            val propertySource = MapPropertySource("aws-secrets-manager", secrets)
            environment.propertySources.addFirst(propertySource)
            log.info("Loaded ${secrets.size} properties from AWS Secrets Manager")
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
            log.warn("Failed to load secret '$secretName': ${e.message}")
            null
        }
    }
}