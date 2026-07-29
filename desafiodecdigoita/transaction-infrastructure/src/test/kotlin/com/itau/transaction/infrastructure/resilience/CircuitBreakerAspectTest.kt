package com.itau.transaction.infrastructure.resilience

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.Signature
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.*

class CircuitBreakerAspectTest {

    private lateinit var circuitBreakerRegistry: CircuitBreakerRegistry
    private lateinit var aspect: CircuitBreakerAspect
    private lateinit var joinPoint: ProceedingJoinPoint
    private lateinit var signature: Signature

    @BeforeEach
    fun setUp() {
        circuitBreakerRegistry = CircuitBreakerRegistry.ofDefaults()
        aspect = CircuitBreakerAspect(circuitBreakerRegistry)
        joinPoint = mock()
        signature = mock()
        whenever(joinPoint.signature).thenReturn(signature)
    }

    @Test
    fun `handleCircuitBreaker should execute method successfully`() {
        whenever(signature.name).thenReturn("testMethod")
        whenever(joinPoint.proceed()).thenReturn("result")

        val annotation = mock<com.itau.transaction.infrastructure.resilience.CircuitBreaker>()
        whenever(annotation.name).thenReturn("testCB")

        val result = aspect.handleCircuitBreaker(joinPoint, annotation)

        assertEquals("result", result)
        verify(joinPoint).proceed()
    }

    @Test
    fun `handleCircuitBreaker should propagate exception`() {
        whenever(signature.name).thenReturn("testMethod")
        whenever(joinPoint.proceed()).thenThrow(RuntimeException("boom"))

        val annotation = mock<com.itau.transaction.infrastructure.resilience.CircuitBreaker>()
        whenever(annotation.name).thenReturn("testCB")

        assertThrows(RuntimeException::class.java) {
            aspect.handleCircuitBreaker(joinPoint, annotation)
        }
    }

    @Test
    fun `handleCircuitBreaker should use named circuit breaker from registry`() {
        whenever(signature.name).thenReturn("testMethod")
        whenever(joinPoint.proceed()).thenReturn("ok")

        val annotation = mock<com.itau.transaction.infrastructure.resilience.CircuitBreaker>()
        whenever(annotation.name).thenReturn("myCustomCB")

        aspect.handleCircuitBreaker(joinPoint, annotation)

        val cb = circuitBreakerRegistry.circuitBreaker("myCustomCB")
        assertNotNull(cb)
        assertEquals("myCustomCB", cb.name)
    }
}