package com.itau.transaction.domain.service

import com.itau.transaction.domain.exception.AccountDisabledException
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.exception.InsufficientBalanceException
import com.itau.transaction.domain.model.*
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import org.slf4j.LoggerFactory
import java.time.Instant

class TransactionAuthorizationService(
    private val accountRepository: AccountRepositoryPort,
    private val transactionRepository: TransactionRepositoryPort
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun authorize(transactionId: String, accountId: String, type: TransactionType, amount: Money): Transaction {
        logger.info("Authorizing transaction {} for account {} type={} amount={}", transactionId, accountId, type, amount)

        val account = accountRepository.findById(accountId)
            .orElseThrow { AccountNotFoundException(accountId) }

        if (!account.isEnabled()) {
            throw AccountDisabledException(accountId)
        }

        val (updatedAccount, transactionStatus) = when (type) {
            TransactionType.CREDIT -> {
                val updated = account.credit(amount)
                accountRepository.save(updated)
                Pair(updated, TransactionStatus.SUCCEEDED)
            }
            TransactionType.DEBIT -> {
                if (account.balance.amount < amount.amount) {
                    logger.warn("Insufficient balance for account {}: current={}, requested={}", accountId, account.balance.amount, amount.amount)
                    throw InsufficientBalanceException(account.balance.amount, amount.amount)
                }
                val updated = account.debit(amount)
                accountRepository.save(updated)
                Pair(updated, TransactionStatus.SUCCEEDED)
            }
        }

        val transaction = Transaction(
            id = transactionId,
            accountId = accountId,
            type = type,
            amount = amount,
            status = transactionStatus,
            timestamp = Instant.now(),
            createdAt = Instant.now()
        )

        val savedTransaction = transactionRepository.save(transaction)
        logger.info("Transaction {} authorized successfully. New balance={}", transactionId, updatedAccount.balance.amount)

        return savedTransaction
    }
}