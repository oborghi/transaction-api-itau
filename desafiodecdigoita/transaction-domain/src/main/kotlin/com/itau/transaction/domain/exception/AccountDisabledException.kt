package com.itau.transaction.domain.exception

class AccountDisabledException(accountId: String) :
    RuntimeException("Account with id $accountId is disabled")