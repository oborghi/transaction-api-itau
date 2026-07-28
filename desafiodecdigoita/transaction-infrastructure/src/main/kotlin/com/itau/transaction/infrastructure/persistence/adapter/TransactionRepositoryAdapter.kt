package com.itau.transaction.infrastructure.persistence.adapter

import com.itau.transaction.domain.model.Transaction
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.infrastructure.persistence.mapper.TransactionDocumentMapper
import com.itau.transaction.infrastructure.persistence.repository.TransactionMongoRepository
import org.springframework.stereotype.Component

@Component
class TransactionRepositoryAdapter(
    private val transactionMongoRepository: TransactionMongoRepository
) : TransactionRepositoryPort {

    override fun save(transaction: Transaction): Transaction {
        val document = TransactionDocumentMapper.toDocument(transaction)
        val saved = transactionMongoRepository.save(document)
        return TransactionDocumentMapper.toDomain(saved)
    }

    override fun findById(id: String): Transaction? {
        return transactionMongoRepository.findById(id)
            .map { TransactionDocumentMapper.toDomain(it) }
            .orElse(null)
    }
}