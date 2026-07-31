package com.itau.transaction.infrastructure.config

import com.amazonaws.xray.AWSXRay
import com.amazonaws.xray.AWSXRayRecorderBuilder
import com.amazonaws.xray.jakarta.servlet.AWSXRayServletFilter
import com.amazonaws.xray.strategy.sampling.NoSamplingStrategy
import jakarta.servlet.Filter
import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class XRayConfig {

    private val log = LoggerFactory.getLogger(XRayConfig::class.java)

    init {
        try {
            val builder = AWSXRayRecorderBuilder.standard()
            builder.withSamplingStrategy(NoSamplingStrategy())
            AWSXRay.setGlobalRecorder(builder.build())
            log.info("AWS X-Ray recorder initialized with NoSamplingStrategy")
        } catch (e: Exception) {
            log.warn("Failed to initialize X-Ray recorder: ${e.message}")
        }
    }

    @Bean
    fun xRayServletFilter(): Filter {
        return AWSXRayServletFilter("transaction-api")
    }
}