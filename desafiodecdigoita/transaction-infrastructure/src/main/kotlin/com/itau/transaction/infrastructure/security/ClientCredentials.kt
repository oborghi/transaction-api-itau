package com.itau.transaction.infrastructure.security

data class ClientCredentials(
    val id: String,
    val secret: String,
    val roles: List<String>
)