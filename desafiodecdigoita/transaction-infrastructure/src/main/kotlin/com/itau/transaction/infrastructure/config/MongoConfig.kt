package com.itau.transaction.infrastructure.config

import org.springframework.context.annotation.Configuration
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories

@Configuration
@EnableMongoRepositories(basePackages = ["com.itau.transaction.infrastructure.persistence.repository"])
class MongoConfig