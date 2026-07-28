package com.itau.transaction.infrastructure.persistence.entity

import org.springframework.data.annotation.Id
import org.springframework.data.mongodb.core.mapping.Document
import java.math.BigDecimal
import java.time.Instant

@Document(collection = "transactions")
data class TransactionDocument(
    @Id
    val id: String,
    val accountId: String,
    val type: String,
    val amountValue: BigDecimal,
    val amountCurrency: String,
    val status: String,
    val timestamp: Instant,
    val createdAt: Instant
)