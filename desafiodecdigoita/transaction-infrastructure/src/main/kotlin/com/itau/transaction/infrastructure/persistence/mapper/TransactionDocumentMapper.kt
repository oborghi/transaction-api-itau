package com.itau.transaction.infrastructure.persistence.mapper

import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.model.Transaction
import com.itau.transaction.domain.model.TransactionStatus
import com.itau.transaction.domain.model.TransactionType
import com.itau.transaction.infrastructure.persistence.entity.TransactionDocument

object TransactionDocumentMapper {

    fun toDocument(transaction: Transaction): TransactionDocument {
        return TransactionDocument(
            id = transaction.id,
            accountId = transaction.accountId,
            type = transaction.type.name,
            amountValue = transaction.amount.amount,
            amountCurrency = transaction.amount.currency,
            status = transaction.status.name,
            timestamp = transaction.timestamp,
            createdAt = transaction.createdAt
        )
    }

    fun toDomain(document: TransactionDocument): Transaction {
        return Transaction(
            id = document.id,
            accountId = document.accountId,
            type = TransactionType.valueOf(document.type),
            amount = Money(amount = document.amountValue, currency = document.amountCurrency),
            status = TransactionStatus.valueOf(document.status),
            timestamp = document.timestamp,
            createdAt = document.createdAt
        )
    }
}