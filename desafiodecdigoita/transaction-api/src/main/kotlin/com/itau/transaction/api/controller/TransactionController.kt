package com.itau.transaction.api.controller

import com.itau.transaction.application.dto.request.TransactionRequest
import com.itau.transaction.application.dto.response.TransactionAuthorizationResponse
import com.itau.transaction.application.service.AuthorizeTransactionUseCase
import jakarta.validation.Valid
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/transactions")
class TransactionController(
    private val authorizeTransactionUseCase: AuthorizeTransactionUseCase
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @PostMapping("/{transactionId}")
    fun authorizeTransaction(
        @PathVariable transactionId: String,
        @Valid @RequestBody request: TransactionRequest
    ): ResponseEntity<TransactionAuthorizationResponse> {
        logger.info("POST /api/v1/transactions/{} type={} amount={}", transactionId, request.type, request.amount?.value)

        val response = authorizeTransactionUseCase.execute(transactionId, request)
        return ResponseEntity.status(HttpStatus.OK).body(response)
    }
}
