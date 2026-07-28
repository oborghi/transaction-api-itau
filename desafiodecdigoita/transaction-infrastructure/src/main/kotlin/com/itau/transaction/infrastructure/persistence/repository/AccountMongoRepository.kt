package com.itau.transaction.infrastructure.persistence.repository

import com.itau.transaction.infrastructure.persistence.entity.AccountDocument
import org.springframework.data.mongodb.repository.MongoRepository

interface AccountMongoRepository : MongoRepository<AccountDocument, String>