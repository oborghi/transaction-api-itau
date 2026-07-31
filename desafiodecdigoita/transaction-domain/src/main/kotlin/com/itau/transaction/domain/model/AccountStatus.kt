package com.itau.transaction.domain.model

enum class AccountStatus {
    ENABLED,
    DISABLED;

    companion object {
        fun fromString(value: String): AccountStatus {
            return when (value.uppercase()) {
                "ACTIVE", "ENABLED" -> ENABLED
                "INACTIVE", "DISABLED" -> DISABLED
                else -> throw IllegalArgumentException("No enum constant $value - valid values: ACTIVE, ENABLED, INACTIVE, DISABLED")
            }
        }
    }
}
