package com.itau.transaction.application.port

/**
 * Port for recording application metrics.
 * Implemented by the infrastructure layer (e.g., Prometheus/Micrometer).
 */
interface MetricsPort {
    fun recordTransaction(type: String, status: String)
    fun <T> recordAuthorizationLatency(block: () -> T): T
    fun updateAccountBalance(accountId: String, balance: Double)
    fun recordSqsMessageConsumed()
    fun recordSqsMessageFailed()
}