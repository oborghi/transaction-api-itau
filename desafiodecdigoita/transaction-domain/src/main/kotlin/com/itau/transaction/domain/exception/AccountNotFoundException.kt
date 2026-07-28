package com.itau.transaction.domain.exception

class AccountNotFoundException(accountId: String) :
    RuntimeException("Account with id $accountId was not found")