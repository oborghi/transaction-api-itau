package com.itau.transaction.domain.port

import com.itau.transaction.domain.model.Account
import java.util.Optional

interface AccountRepositoryPort {
    fun findById(id: String): Optional<Account>
    fun save(account: Account): Account
    fun existsById(id: String): Boolean
}