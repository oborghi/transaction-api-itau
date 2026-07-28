package com.itau.transaction.domain.model

import java.time.Instant

data class Account(
    val id: String,
    val owner: String,
    val balance: Money,
    val status: AccountStatus,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
    val version: Long = 0
) {
    fun isEnabled(): Boolean = status == AccountStatus.ENABLED

    fun credit(amount: Money): Account {
        require(amount.currency == balance.currency) {
            "Currency mismatch: account uses ${balance.currency}, transaction uses ${amount.currency}"
        }
        return copy(
            balance = balance + amount,
            updatedAt = Instant.now(),
            version = version + 1
        )
    }

    fun debit(amount: Money): Account {
        require(amount.currency == balance.currency) {
            "Currency mismatch: account uses ${balance.currency}, transaction uses ${amount.currency}"
        }
        return copy(
            balance = balance - amount,
            updatedAt = Instant.now(),
            version = version + 1
        )
    }
}