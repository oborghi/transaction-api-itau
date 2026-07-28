package com.itau.transaction.infrastructure.config

import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.domain.service.AccountRegistrationService
import com.itau.transaction.domain.service.TransactionAuthorizationService
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class DomainServiceConfig {

    @Bean
    fun transactionAuthorizationService(
        accountRepository: AccountRepositoryPort,
        transactionRepository: TransactionRepositoryPort
    ): TransactionAuthorizationService {
        return TransactionAuthorizationService(accountRepository, transactionRepository)
    }

    @Bean
    fun accountRegistrationService(
        accountRepository: AccountRepositoryPort
    ): AccountRegistrationService {
        return AccountRegistrationService(accountRepository)
    }
}