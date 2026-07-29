package com.itau.transaction.infrastructure.config

import io.micrometer.core.instrument.simple.SimpleMeterRegistry
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class TransactionMetricsTest {

    private lateinit var meterRegistry: SimpleMeterRegistry
    private lateinit var metrics: TransactionMetrics

    @BeforeEach
    fun setUp() {
        meterRegistry = SimpleMeterRegistry()
        metrics = TransactionMetrics(meterRegistry)
    }

    @Test
    fun `recordTransaction should increment counter with correct tags`() {
        metrics.recordTransaction("CREDIT", "SUCCEEDED")
        metrics.recordTransaction("CREDIT", "SUCCEEDED")
        metrics.recordTransaction("DEBIT", "FAILED")

        val creditSucceeded = meterRegistry.get("transaction.total")
            .tag("type", "CREDIT")
            .tag("status", "SUCCEEDED")
            .counter()

        val debitFailed = meterRegistry.get("transaction.total")
            .tag("type", "DEBIT")
            .tag("status", "FAILED")
            .counter()

        assertEquals(2.0, creditSucceeded!!.count())
        assertEquals(1.0, debitFailed!!.count())
    }

    @Test
    fun `recordAuthorizationLatency should record timing`() {
        val result = metrics.recordAuthorizationLatency { "success" }

        assertEquals("success", result)

        val timer = meterRegistry.get("transaction.authorization.latency").timer()
        assertNotNull(timer)
        assertEquals(1, timer.count())
        assertTrue(timer.totalTime(java.util.concurrent.TimeUnit.NANOSECONDS) > 0)
    }

    @Test
    fun `recordSqsMessageConsumed should increment counter`() {
        metrics.recordSqsMessageConsumed()
        metrics.recordSqsMessageConsumed()

        val counter = meterRegistry.get("sqs.messages.consumed").counter()
        assertEquals(2.0, counter.count())
    }

    @Test
    fun `recordSqsMessageFailed should increment counter`() {
        metrics.recordSqsMessageFailed()

        val counter = meterRegistry.get("sqs.messages.failed").counter()
        assertEquals(1.0, counter.count())
    }

    @Test
    fun `recordDlqMessageReprocessed should increment counter with status tag`() {
        metrics.recordDlqMessageReprocessed(true)
        metrics.recordDlqMessageReprocessed(true)
        metrics.recordDlqMessageReprocessed(false)

        val successCounter = meterRegistry.get("dlq.messages.reprocessed")
            .tag("status", "success")
            .counter()

        val failedCounter = meterRegistry.get("dlq.messages.reprocessed")
            .tag("status", "failed")
            .counter()

        assertEquals(2.0, successCounter.count())
        assertEquals(1.0, failedCounter.count())
    }

    @Test
    fun `updateAccountBalance should track balances`() {
        metrics.updateAccountBalance("acc-1", 100.0)
        metrics.updateAccountBalance("acc-2", 200.0)

        assertEquals(150.0, metrics.getAverageBalance())
    }

    @Test
    fun `getAverageBalance should return 0 for empty accounts`() {
        assertEquals(0.0, metrics.getAverageBalance())
    }

    @Test
    fun `account balance avg gauge should be registered`() {
        metrics.updateAccountBalance("acc-1", 100.0)

        val gauge = meterRegistry.get("account.balance.avg").gauge()
        assertNotNull(gauge)
        assertEquals(100.0, gauge!!.value())
    }

    @Test
    fun `account total gauge should be registered`() {
        metrics.updateAccountBalance("acc-1", 100.0)
        metrics.updateAccountBalance("acc-2", 200.0)

        val gauge = meterRegistry.get("account.total").gauge()
        assertNotNull(gauge)
        assertEquals(2.0, gauge!!.value())
    }

    @Test
    fun `account total gauge should reflect updated balances`() {
        metrics.updateAccountBalance("acc-1", 100.0)
        metrics.updateAccountBalance("acc-2", 200.0)
        // Update existing account
        metrics.updateAccountBalance("acc-1", 150.0)

        val gauge = meterRegistry.get("account.total").gauge()
        assertEquals(2.0, gauge!!.value()) // Still 2 accounts
        assertEquals(175.0, metrics.getAverageBalance()) // (150+200)/2
    }

    @Test
    fun `recordAuthorizationLatency should return block result`() {
        val result = metrics.recordAuthorizationLatency { 42 }

        assertEquals(42, result)
    }

    @Test
    fun `recordAuthorizationLatency should handle exception in block`() {
        assertThrows(RuntimeException::class.java) {
            metrics.recordAuthorizationLatency {
                throw RuntimeException("test error")
            }
        }
    }
}