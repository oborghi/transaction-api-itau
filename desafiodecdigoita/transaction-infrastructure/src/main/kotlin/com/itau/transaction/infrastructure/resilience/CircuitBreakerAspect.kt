package com.itau.transaction.infrastructure.resilience

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

/**
 * AOP aspect that automatically applies Circuit Breaker pattern to annotated methods.
 *
 * Usage:
 *   @CircuitBreaker(name = "mongoDbCircuitBreaker")
 *   fun someMethod() { ... }
 *
 * Circuit Breaker states:
 * - CLOSED: Normal operation, calls pass through
 * - OPEN: Too many failures, calls are rejected
 * - HALF_OPEN: Testing if service recovered, limited calls allowed
 */
@Aspect
@Component("customCircuitBreakerAspect")
class CircuitBreakerAspect(
    private val circuitBreakerRegistry: CircuitBreakerRegistry
) {

    private val log = LoggerFactory.getLogger(CircuitBreakerAspect::class.java)

    @Around("@annotation(circuitBreakerAnnotation)")
    fun handleCircuitBreaker(joinPoint: ProceedingJoinPoint, circuitBreakerAnnotation: CircuitBreaker): Any? {
        val circuitBreakerName = circuitBreakerAnnotation.name
        val circuitBreaker = circuitBreakerRegistry.circuitBreaker(circuitBreakerName)

        log.debug("Executing ${joinPoint.signature.name} with CircuitBreaker: $circuitBreakerName")

        return circuitBreaker.executeSupplier {
            try {
                joinPoint.proceed()
            } catch (e: Throwable) {
                log.warn("CircuitBreaker [$circuitBreakerName] caught exception: ${e.message}")
                throw e
            }
        }
    }
}

/**
 * Custom annotation for applying Circuit Breaker via AOP.
 */
@Target(AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
annotation class CircuitBreaker(val name: String)