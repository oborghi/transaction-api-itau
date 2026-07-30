package com.itau.transaction.infrastructure.persistence.adapter

import com.itau.transaction.domain.model.Transaction
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.infrastructure.config.XRayTracing
import com.itau.transaction.infrastructure.persistence.mapper.TransactionDocumentMapper
import com.itau.transaction.infrastructure.persistence.repository.TransactionMongoRepository
import org.springframework.stereotype.Component

@Component
class TransactionRepositoryAdapter(
    private val transactionMongoRepository: TransactionMongoRepository
) : TransactionRepositoryPort {

    override fun save(transaction: Transaction): Transaction {
        return XRayTracing.trace("mongodb.query") {
            val document = TransactionDocumentMapper.toDocument(transaction)
            val saved = transactionMongoRepository.save(document)
            TransactionDocumentMapper.toDomain(saved)
        }
    }

    override fun findById(id: String): Transaction? {
        return XRayTracing.trace("mongodb.query") {
            transactionMongoRepository.findById(id)
                .map { TransactionDocumentMapper.toDomain(it) }
                .orElse(null)
        }
    }
}