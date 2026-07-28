package com.itau.transaction.application.dto.response

import java.time.Instant

data class TransactionResponse(
    val id: String,
    val type: String,
    val amount: AmountResponse,
    val status: String,
    val timestamp: Instant
)

data class AmountResponse(
    val value: Double,
    val currency: String
)

data class TransactionAuthorizationResponse(
    val transaction: TransactionResponse,
    val account: AccountResponse
)

data class AccountResponse(
    val id: String,
    val balance: AmountResponse
)