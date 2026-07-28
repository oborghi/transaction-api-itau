package com.itau.transaction.domain.port

import com.itau.transaction.domain.model.Transaction

interface TransactionRepositoryPort {
    fun save(transaction: Transaction): Transaction
    fun findById(id: String): Transaction?
}