package com.itau.transaction.infrastructure.persistence.mapper

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import com.itau.transaction.infrastructure.persistence.entity.AccountDocument

object AccountDocumentMapper {

    fun toDocument(account: Account): AccountDocument {
        return AccountDocument(
            id = account.id,
            owner = account.owner,
            balanceAmount = account.balance.amount,
            balanceCurrency = account.balance.currency,
            status = account.status.name,
            createdAt = account.createdAt,
            updatedAt = account.updatedAt,
            version = account.version
        )
    }

    fun toDomain(document: AccountDocument): Account {
        return Account(
            id = document.id,
            owner = document.owner,
            balance = Money(amount = document.balanceAmount, currency = document.balanceCurrency),
            status = AccountStatus.valueOf(document.status),
            createdAt = document.createdAt,
            updatedAt = document.updatedAt,
            version = document.version
        )
    }
}