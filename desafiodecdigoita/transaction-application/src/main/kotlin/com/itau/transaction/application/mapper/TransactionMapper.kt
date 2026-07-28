package com.itau.transaction.application.mapper

import com.itau.transaction.application.dto.request.AmountRequest
import com.itau.transaction.application.dto.response.AmountResponse
import com.itau.transaction.application.dto.response.TransactionAuthorizationResponse
import com.itau.transaction.application.dto.response.TransactionResponse
import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.model.Transaction

object TransactionMapper {

    fun toMoney(amountRequest: AmountRequest): Money {
        return Money.of(amountRequest.value, amountRequest.currency)
    }

    fun toTransactionResponse(transaction: Transaction): TransactionResponse {
        return TransactionResponse(
            id = transaction.id,
            type = transaction.type.name,
            amount = toAmountResponse(transaction.amount),
            status = transaction.status.name,
            timestamp = transaction.timestamp
        )
    }

    fun toAccountResponse(account: Account): com.itau.transaction.application.dto.response.AccountResponse {
        return com.itau.transaction.application.dto.response.AccountResponse(
            id = account.id,
            balance = toAmountResponse(account.balance)
        )
    }

    fun toAuthorizationResponse(transaction: Transaction, account: Account): TransactionAuthorizationResponse {
        return TransactionAuthorizationResponse(
            transaction = toTransactionResponse(transaction),
            account = toAccountResponse(account)
        )
    }

    private fun toAmountResponse(money: Money): AmountResponse {
        return AmountResponse(
            value = money.amount.toDouble(),
            currency = money.currency
        )
    }
}