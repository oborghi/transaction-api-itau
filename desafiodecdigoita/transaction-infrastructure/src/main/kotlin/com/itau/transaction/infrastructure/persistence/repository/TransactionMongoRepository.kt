package com.itau.transaction.infrastructure.persistence.repository

import com.itau.transaction.infrastructure.persistence.entity.TransactionDocument
import org.springframework.data.mongodb.repository.MongoRepository

interface TransactionMongoRepository : MongoRepository<TransactionDocument, String>