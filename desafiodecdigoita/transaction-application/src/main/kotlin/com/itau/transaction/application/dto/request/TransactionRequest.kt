package com.itau.transaction.application.dto.request

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive

data class TransactionRequest(
    @field:NotBlank(message = "account_id is required")
    val account_id: String,

    @field:NotBlank(message = "type is required")
    val type: String,

    @field:NotNull(message = "amount is required")
    val amount: AmountRequest
)

data class AmountRequest(
    @field:Positive(message = "amount value must be positive")
    val value: Double,

    @field:NotBlank(message = "currency is required")
    val currency: String = "BRL"
)