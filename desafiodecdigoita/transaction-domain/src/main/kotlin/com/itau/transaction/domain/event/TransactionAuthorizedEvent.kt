package com.itau.transaction.domain.event

import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.model.TransactionStatus
import com.itau.transaction.domain.model.TransactionType
import java.time.Instant

data class TransactionAuthorizedEvent(
    val transactionId: String,
    val accountId: String,
    val type: TransactionType,
    val amount: Money,
    val status: TransactionStatus,
    val timestamp: Instant = Instant.now()
)