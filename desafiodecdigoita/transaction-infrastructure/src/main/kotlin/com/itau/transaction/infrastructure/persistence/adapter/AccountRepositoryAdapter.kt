package com.itau.transaction.infrastructure.persistence.adapter

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.infrastructure.config.XRayTracing
import com.itau.transaction.infrastructure.persistence.mapper.AccountDocumentMapper
import com.itau.transaction.infrastructure.persistence.repository.AccountMongoRepository
import org.springframework.stereotype.Component
import java.util.Optional

@Component
class AccountRepositoryAdapter(
    private val accountMongoRepository: AccountMongoRepository
) : AccountRepositoryPort {

    override fun findById(id: String): Optional<Account> {
        return XRayTracing.trace("mongodb.query") {
            accountMongoRepository.findById(id).map { AccountDocumentMapper.toDomain(it) }
        }
    }

    override fun save(account: Account): Account {
        return XRayTracing.trace("mongodb.query") {
            val document = AccountDocumentMapper.toDocument(account)
            val saved = accountMongoRepository.save(document)
            AccountDocumentMapper.toDomain(saved)
        }
    }

    override fun existsById(id: String): Boolean {
        return XRayTracing.trace("mongodb.query") {
            accountMongoRepository.existsById(id)
        }
    }
}
