package com.itau.transaction.infrastructure.config

import com.itau.transaction.application.port.MetricsPort
import io.micrometer.core.instrument.Counter
import io.micrometer.core.instrument.Gauge
import io.micrometer.core.instrument.MeterRegistry
import io.micrometer.core.instrument.Timer
import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap

@Component
class TransactionMetrics(
    private val meterRegistry: MeterRegistry
) : MetricsPort {

    private val accountBalances = ConcurrentHashMap<String, Double>()

    /**
     * Records a transaction event (CREDIT or DEBIT, SUCCEEDED or FAILED).
     */
    override fun recordTransaction(type: String, status: String) {
        Counter.builder("transaction.total")
            .description("Total number of transactions")
            .tag("type", type)
            .tag("status", status)
            .register(meterRegistry)
            .increment()
    }

    /**
     * Records authorization latency and returns the result.
     */
    override fun <T> recordAuthorizationLatency(block: () -> T): T {
        return Timer.builder("transaction.authorization.latency")
            .description("Transaction authorization latency")
            .publishPercentiles(0.5, 0.9, 0.95)
            .publishPercentileHistogram(true)
            .register(meterRegistry)
            .record(block) ?: throw IllegalStateException("Authorization returned null")
    }

    /**
     * Records SQS message consumption.
     */
    override fun recordSqsMessageConsumed() {
        Counter.builder("sqs.messages.consumed")
            .description("Total SQS messages consumed")
            .register(meterRegistry)
            .increment()
    }

    /**
     * Records SQS message failure.
     */
    override fun recordSqsMessageFailed() {
        Counter.builder("sqs.messages.failed")
            .description("Total SQS messages that failed")
            .register(meterRegistry)
            .increment()
    }

    /**
     * Records DLQ message reprocessing.
     */
    fun recordDlqMessageReprocessed(success: Boolean) {
        Counter.builder("dlq.messages.reprocessed")
            .description("Total DLQ messages reprocessed")
            .tag("status", if (success) "success" else "failed")
            .register(meterRegistry)
            .increment()
    }

    /**
     * Updates account balance tracking for gauge.
     */
    override fun updateAccountBalance(accountId: String, balance: Double) {
        accountBalances[accountId] = balance
    }

    /**
     * Returns the average balance across all tracked accounts.
     */
    fun getAverageBalance(): Double {
        return if (accountBalances.isEmpty()) 0.0
        else accountBalances.values.average()
    }

    init {
        // Register gauges
        Gauge.builder("account.balance.avg", this@TransactionMetrics) {
            it.getAverageBalance()
        }
            .description("Average account balance")
            .register(meterRegistry)

        Gauge.builder("account.total", this@TransactionMetrics) {
            it.accountBalances.size.toDouble()
        }
            .description("Total number of registered accounts")
            .register(meterRegistry)
    }
}