package com.itau.transaction.domain.model

import java.time.Instant

data class Transaction(
    val id: String,
    val accountId: String,
    val type: TransactionType,
    val amount: Money,
    val status: TransactionStatus,
    val timestamp: Instant = Instant.now(),
    val createdAt: Instant = Instant.now()
)