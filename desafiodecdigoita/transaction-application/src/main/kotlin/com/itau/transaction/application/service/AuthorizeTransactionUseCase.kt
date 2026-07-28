package com.itau.transaction.application.service

import com.itau.transaction.application.dto.request.TransactionRequest
import com.itau.transaction.application.dto.response.TransactionAuthorizationResponse
import com.itau.transaction.application.mapper.TransactionMapper
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.model.TransactionType
import com.itau.transaction.domain.port.AccountRepositoryPort
import com.itau.transaction.domain.port.TransactionRepositoryPort
import com.itau.transaction.domain.service.TransactionAuthorizationService
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

@Service
class AuthorizeTransactionUseCase(
    private val transactionAuthorizationService: TransactionAuthorizationService,
    private val accountRepository: AccountRepositoryPort,
    private val transactionRepository: TransactionRepositoryPort
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    fun execute(transactionId: String, request: TransactionRequest): TransactionAuthorizationResponse {
        logger.info("Executing authorize transaction use case for id={} account={}", transactionId, request.account_id)

        val money = TransactionMapper.toMoney(request.amount)
        val type = TransactionType.valueOf(request.type)

        val transaction = transactionAuthorizationService.authorize(
            transactionId = transactionId,
            accountId = request.account_id,
            type = type,
            amount = money
        )

        if (transaction == null) {
            throw AccountNotFoundException("Account with id ${request.account_id} was not found")
        }

        val account = accountRepository.findById(request.account_id)
            .orElseThrow { AccountNotFoundException("Account with id ${request.account_id} was not found") }

        return TransactionMapper.toAuthorizationResponse(transaction, account)
    }
}