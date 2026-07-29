package com.itau.transaction.api.exception

import com.itau.transaction.domain.exception.AccountDisabledException
import com.itau.transaction.domain.exception.AccountNotFoundException
import com.itau.transaction.domain.exception.InsufficientBalanceException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ControllerAdvice
import com.itau.transaction.application.port.MetricsPort
import org.springframework.web.bind.annotation.ExceptionHandler

@ControllerAdvice
class GlobalExceptionHandler(
    private val metricsPort: MetricsPort
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @ExceptionHandler(AccountNotFoundException::class)
    fun handleAccountNotFound(ex: AccountNotFoundException): ResponseEntity<ErrorResponse> {
        logger.warn("Account not found: {}", ex.message)
        metricsPort.recordTransaction("UNKNOWN", "FAILED") // Record the failure metric
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
            ErrorResponse(
                error = "ACCOUNT_NOT_FOUND",
                message = ex.message ?: "Account not found"
            )
        )
    }

    @ExceptionHandler(InsufficientBalanceException::class)
    fun handleInsufficientBalance(ex: InsufficientBalanceException): ResponseEntity<ErrorResponse> {
        logger.warn("Insufficient balance: {}", ex.message)
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
            ErrorResponse(
                error = "INSUFFICIENT_BALANCE",
                message = ex.message ?: "Insufficient balance"
            )
        )
    }

    @ExceptionHandler(AccountDisabledException::class)
    fun handleAccountDisabled(ex: AccountDisabledException): ResponseEntity<ErrorResponse> {
        logger.warn("Account disabled: {}", ex.message)
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(
            ErrorResponse(
                error = "ACCOUNT_DISABLED",
                message = ex.message ?: "Account is disabled"
            )
        )
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ResponseEntity<ErrorResponse> {
        val message = ex.bindingResult.fieldErrors.joinToString(", ") { "${it.field}: ${it.defaultMessage}" }
        logger.warn("Validation error: {}", message)
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(
            ErrorResponse(
                error = "VALIDATION_ERROR",
                message = message
            )
        )
    }

    @ExceptionHandler(HttpMessageNotReadableException::class, IllegalArgumentException::class)
    fun handleBadRequest(ex: Exception): ResponseEntity<ErrorResponse> {
        logger.warn("Invalid request: {}", ex.message)
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(
            ErrorResponse(
                error = "INVALID_REQUEST",
                message = "Invalid request payload"
            )
        )
    }

    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception): ResponseEntity<ErrorResponse> {
        logger.error("Unexpected error: {}", ex.message, ex)
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(
            ErrorResponse(
                error = "INTERNAL_ERROR",
                message = "An unexpected error occurred"
            )
        )
    }
}