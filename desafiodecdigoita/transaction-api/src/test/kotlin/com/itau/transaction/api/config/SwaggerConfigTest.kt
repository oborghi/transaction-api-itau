package com.itau.transaction.api.config

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class SwaggerConfigTest {

    @Test
    fun `should create OpenAPI configuration`() {
        val config = SwaggerConfig()

        val openAPI = config.openAPI()

        assertNotNull(openAPI)
        assertNotNull(openAPI.info)
    }

    @Test
    fun `should have correct API title`() {
        val config = SwaggerConfig()
        val openAPI = config.openAPI()

        assertEquals("Transaction API", openAPI.info.title)
    }

    @Test
    fun `should have correct API description`() {
        val config = SwaggerConfig()
        val openAPI = config.openAPI()

        assertEquals("API de Autorização de Transações Financeiras", openAPI.info.description)
    }

    @Test
    fun `should have correct API version`() {
        val config = SwaggerConfig()
        val openAPI = config.openAPI()

        assertEquals("1.0.0", openAPI.info.version)
    }
}