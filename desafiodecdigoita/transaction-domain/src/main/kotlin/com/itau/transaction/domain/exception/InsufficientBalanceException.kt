package com.itau.transaction.domain.exception

import java.math.BigDecimal

class InsufficientBalanceException(
    currentBalance: BigDecimal,
    requestedAmount: BigDecimal
) : RuntimeException(
    "Account has insufficient balance for debit transaction. Current: $currentBalance, Requested: $requestedAmount"
)