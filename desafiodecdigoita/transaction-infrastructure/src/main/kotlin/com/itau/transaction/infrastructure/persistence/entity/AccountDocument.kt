package com.itau.transaction.infrastructure.persistence.entity

import org.springframework.data.annotation.Id
import org.springframework.data.mongodb.core.mapping.Document
import java.math.BigDecimal
import java.time.Instant

@Document(collection = "accounts")
data class AccountDocument(
    @Id
    val id: String,
    val owner: String,
    val balanceAmount: BigDecimal,
    val balanceCurrency: String,
    val status: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val version: Long
)