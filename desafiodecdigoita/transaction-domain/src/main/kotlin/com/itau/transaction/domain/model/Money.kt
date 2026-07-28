package com.itau.transaction.domain.model

import java.math.BigDecimal
import java.math.RoundingMode

data class Money(
    val amount: BigDecimal,
    val currency: String = "BRL"
) {
    init {
        require(currency.isNotBlank()) { "Currency must not be blank" }
    }

    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies: $currency vs ${other.currency}" }
        return Money(amount = amount.add(other.amount).setScale(2, RoundingMode.HALF_UP), currency = currency)
    }

    operator fun minus(other: Money): Money {
        require(currency == other.currency) { "Cannot subtract different currencies: $currency vs ${other.currency}" }
        return Money(amount = amount.subtract(other.amount).setScale(2, RoundingMode.HALF_UP), currency = currency)
    }

    fun isNegative(): Boolean = amount < BigDecimal.ZERO

    companion object {
        fun of(value: Double, currency: String = "BRL"): Money =
            Money(amount = BigDecimal.valueOf(value).setScale(2, RoundingMode.HALF_UP), currency = currency)

        fun zero(currency: String = "BRL"): Money =
            Money(amount = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP), currency = currency)
    }
}