package com.itau.transaction.domain.port

interface EventPublisherPort {
    fun publish(event: Any)
}