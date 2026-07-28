package com.itau.transaction.api.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.cloud.context.config.annotation.RefreshScope
import org.springframework.stereotype.Component

@Component
@RefreshScope
class ConsulConfig {

    private val log = LoggerFactory.getLogger(javaClass)

    @Value("\${app.security.jwt.secret:MyDefaultSecretKeyForDevelopmentOnly2024!}")
    lateinit var jwtSecret: String

    @Value("\${app.security.jwt.expiration:86400}")
    var jwtExpiration: Long = 86400

    @Value("\${app.sqs.queue-url:http://localhost:4566/000000000000/conta-bancaria-criada}")
    lateinit var sqsQueueUrl: String

    @Value("\${resilience4j.circuitbreaker.instances.mongoDbCircuitBreaker.failureRateThreshold:50}")
    var circuitBreakerThreshold: Int = 50

    @Value("\${management.metrics.export.prometheus.enabled:true}")
    var prometheusEnabled: Boolean = true

    fun logCurrentConfig() {
        log.info(
            "Current config from Consul: jwtExpiration={}, circuitBreakerThreshold={}, prometheusEnabled={}",
            jwtExpiration, circuitBreakerThreshold, prometheusEnabled
        )
    }
}