package com.itau.transaction.domain.event

import java.time.Instant

data class AccountCreatedEvent(
    val accountId: String,
    val owner: String,
    val status: String,
    val createdAt: Instant = Instant.now()
)