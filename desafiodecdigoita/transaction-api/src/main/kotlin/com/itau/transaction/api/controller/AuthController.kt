package com.itau.transaction.api.controller

import com.itau.transaction.infrastructure.security.JwtTokenProvider
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val jwtTokenProvider: JwtTokenProvider,

    @Value("\${app.security.clients[0].id}")
    private val validClientId: String,

    @Value("\${app.security.clients[0].secret}")
    private val validClientSecret: String
) {

    @PostMapping("/token")
    fun generateToken(@RequestBody request: AuthRequest): ResponseEntity<AuthResponse> {
        if (request.client_id.isBlank() || request.client_secret.isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                AuthResponse(
                    error = "UNAUTHORIZED",
                    message = "Invalid client credentials"
                )
            )
        }

        if (request.client_id != validClientId || request.client_secret != validClientSecret) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                AuthResponse(
                    error = "UNAUTHORIZED",
                    message = "Invalid client credentials"
                )
            )
        }

        val token = jwtTokenProvider.generateToken(request.client_id, listOf("ADMIN", "API"))
        val expiresAt = jwtTokenProvider.getExpiration(token)
        val expiresAtStr = expiresAt.toInstant()
            .atZone(ZoneId.of("America/Sao_Paulo"))
            .format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)

        return ResponseEntity.ok(
            AuthResponse(
                token = token,
                token_type = "Bearer",
                expires_in = 86400,
                expires_at = expiresAtStr
            )
        )
    }
}

data class AuthRequest(
    val client_id: String,
    val client_secret: String
)

data class AuthResponse(
    val token: String? = null,
    val token_type: String? = null,
    val expires_in: Long? = null,
    val expires_at: String? = null,
    val error: String? = null,
    val message: String? = null
)