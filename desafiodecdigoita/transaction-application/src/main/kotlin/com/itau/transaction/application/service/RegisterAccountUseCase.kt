package com.itau.transaction.application.service

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.service.AccountRegistrationService
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

@Service
class RegisterAccountUseCase(
    private val accountRegistrationService: AccountRegistrationService
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun execute(accountId: String, owner: String, status: String): Account {
        logger.info("Executing register account use case for id={} owner={}", accountId, owner)
        return accountRegistrationService.register(accountId, owner, status)
    }
}