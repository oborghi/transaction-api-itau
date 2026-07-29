package com.itau.transaction.api.integration

import com.github.benmanes.caffeine.cache.Caffeine
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.cache.CacheManager
import org.springframework.cache.caffeine.CaffeineCacheManager
import org.springframework.context.annotation.Bean
import java.time.Duration

@TestConfiguration(proxyBeanMethods = false)
class IntegrationTestCacheConfig {

    @Bean
    fun integrationTestCacheManager(): CacheManager =
        CaffeineCacheManager("jwt-tokens").apply {
            setCaffeine(
                Caffeine.newBuilder()
                    .maximumSize(1_000)
                    .expireAfterWrite(Duration.ofHours(24))
                    .recordStats()
            )
        }
}