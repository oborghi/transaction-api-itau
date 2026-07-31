package com.itau.transaction.domain.service

import com.itau.transaction.domain.model.Account
import com.itau.transaction.domain.model.AccountStatus
import com.itau.transaction.domain.model.Money
import com.itau.transaction.domain.port.AccountRepositoryPort
import org.slf4j.LoggerFactory
import java.time.Instant

class AccountRegistrationService(
    private val accountRepository: AccountRepositoryPort
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun register(id: String, owner: String, status: String): Account {
        logger.info("Registering account id={} owner={}", id, owner)

        if (accountRepository.existsById(id)) {
            logger.info("Account {} already exists, skipping registration", id)
            return accountRepository.findById(id).get()
        }

        val account = Account(
            id = id,
            owner = owner,
            balance = Money.zero(),
            status = AccountStatus.fromString(status),
            createdAt = Instant.now(),
            updatedAt = Instant.now(),
            version = 0
        )

        val saved = accountRepository.save(account)
        logger.info("Account {} registered successfully with balance={}", id, saved.balance.amount)

        return saved
    }
}