package com.itau.transaction.api.config

import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.boot.SpringApplication
import org.springframework.boot.env.EnvironmentPostProcessor
import org.springframework.core.env.ConfigurableEnvironment
import org.springframework.core.env.MapPropertySource
import org.springframework.http.HttpEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpMethod
import org.springframework.http.MediaType
import org.springframework.web.client.RestTemplate

/**
 * Loads secrets from HashiCorp Vault at startup and injects them as Spring properties.
 * Works in both Docker (Vault) and AWS (Secrets Manager) environments.
 *
 * Vault KV v2 path structure:
 *   secret/transaction-api/mongodb → { "uri": "...", "username": "...", "password": "..." }
 *   secret/transaction-api/jwt → { "secret": "...", "issuer": "..." }
 *   secret/transaction-api/credentials → { "client_id": "...", "client_secret": "..." }
 */
class VaultSecretLoader : EnvironmentPostProcessor {

    private val log = LoggerFactory.getLogger(VaultSecretLoader::class.java)
    private val restTemplate = RestTemplate()
    private val objectMapper = ObjectMapper()

    override fun postProcessEnvironment(environment: ConfigurableEnvironment, application: SpringApplication) {
        // Check if Vault is enabled (uses app.vault.enabled to decouple from Spring Cloud Vault)
        val vaultEnabled = environment.getProperty("app.vault.enabled", "false")
        if (vaultEnabled != "true") {
            log.info("Vault integration disabled. Using default configuration.")
            return
        }

        val vaultHost = environment.getProperty("app.vault.host", "localhost")
        val vaultPort = environment.getProperty("app.vault.port", "8200")
        val vaultScheme = environment.getProperty("app.vault.scheme", "http")
        val vaultToken = environment.getProperty("app.vault.token", "")

        if (vaultToken.isBlank()) {
            log.warn("No Vault token configured. Skipping Vault secret loading.")
            return
        }

        val vaultUrl = "$vaultScheme://$vaultHost:$vaultPort"
        log.info("Loading secrets from Vault at $vaultUrl")

        val secrets = mutableMapOf<String, Any>()

        // Load MongoDB secrets
        loadSecret(vaultUrl, vaultToken, "transaction-api/mongodb")?.let { mongoProps ->
            mongoProps["uri"]?.let { secrets["spring.data.mongodb.uri"] = it }
            log.info("Loaded MongoDB secret from Vault")
        }

        // Load JWT secrets
        loadSecret(vaultUrl, vaultToken, "transaction-api/jwt")?.let { jwtProps ->
            jwtProps["secret"]?.let { secrets["app.security.jwt.secret"] = it }
            jwtProps["issuer"]?.let { secrets["app.security.jwt.issuer"] = it }
            log.info("Loaded JWT secret from Vault")
        }

        // Load API credentials
        loadSecret(vaultUrl, vaultToken, "transaction-api/credentials")?.let { credProps ->
            credProps["client_id"]?.let { secrets["app.security.client.id"] = it }
            credProps["client_secret"]?.let { secrets["app.security.client.secret"] = it }
            log.info("Loaded API credentials from Vault")
        }

        // Load AWS/SQS secrets
        loadSecret(vaultUrl, vaultToken, "transaction-api/sqs")?.let { sqsProps ->
            sqsProps["endpoint"]?.let { secrets["aws.endpoint-url"] = it }
            sqsProps["region"]?.let { secrets["aws.region"] = it }
            sqsProps["access_key"]?.let { secrets["aws.access-key-id"] = it }
            sqsProps["secret_key"]?.let { secrets["aws.secret-access-key"] = it }
            log.info("Loaded AWS/SQS secrets from Vault")
        }

        if (secrets.isNotEmpty()) {
            val propertySource = MapPropertySource("vault-secrets", secrets)
            environment.propertySources.addFirst(propertySource)
            log.info("Successfully loaded ${secrets.size} properties from Vault")
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun loadSecret(vaultUrl: String, token: String, path: String): Map<String, Any>? {
        return try {
            val headers = HttpHeaders().apply {
                contentType = MediaType.APPLICATION_JSON
                set("X-Vault-Token", token)
            }
            val entity = HttpEntity(null, headers)

            // KV v2 read endpoint
            val response = restTemplate.exchange(
                "$vaultUrl/v1/secret/data/$path",
                HttpMethod.GET,
                entity,
                String::class.java
            )

            if (response.statusCode.is2xxSuccessful) {
                val jsonNode = objectMapper.readTree(response.body)
                // KV v2 wraps data in data.data
                val data = jsonNode.path("data").path("data")
                objectMapper.convertValue(data, Map::class.java) as? Map<String, Any>
            } else {
                log.warn("Failed to load secret from Vault path '$path': HTTP ${response.statusCode}")
                null
            }
        } catch (e: Exception) {
            log.warn("Failed to load secret from Vault path '$path': ${e.message}")
            null
        }
    }
}