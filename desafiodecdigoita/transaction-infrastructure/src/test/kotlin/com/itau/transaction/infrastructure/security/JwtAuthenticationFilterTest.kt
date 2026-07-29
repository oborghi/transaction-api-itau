package com.itau.transaction.infrastructure.security

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.*
import org.springframework.security.core.context.SecurityContextHolder

class JwtAuthenticationFilterTest {

    private lateinit var jwtTokenProvider: JwtTokenProvider
    private lateinit var filter: JwtAuthenticationFilter
    private lateinit var request: HttpServletRequest
    private lateinit var response: HttpServletResponse
    private lateinit var filterChain: FilterChain

    @BeforeEach
    fun setUp() {
        jwtTokenProvider = mock()
        filter = JwtAuthenticationFilter(jwtTokenProvider)
        request = mock()
        response = mock()
        filterChain = mock()
        SecurityContextHolder.clearContext()
    }

    @Test
    fun `doFilter should set authentication when valid token`() {
        whenever(request.getHeader("Authorization")).thenReturn("Bearer valid-token")
        whenever(jwtTokenProvider.validateToken("valid-token")).thenReturn(true)
        whenever(jwtTokenProvider.validateAndGetSubject("valid-token")).thenReturn("user-123")

        filter.doFilter(request, response, filterChain)

        val auth = SecurityContextHolder.getContext().authentication
        assertNotNull(auth)
        assertEquals("user-123", auth.principal)
        assertNull(auth.credentials)
        assertTrue(auth.authorities.isEmpty())
        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `doFilter should not set authentication when token is invalid`() {
        whenever(request.getHeader("Authorization")).thenReturn("Bearer invalid-token")
        whenever(jwtTokenProvider.validateToken("invalid-token")).thenReturn(false)

        filter.doFilter(request, response, filterChain)

        val auth = SecurityContextHolder.getContext().authentication
        assertNull(auth)
        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `doFilter should not set authentication when no Authorization header`() {
        whenever(request.getHeader("Authorization")).thenReturn(null)

        filter.doFilter(request, response, filterChain)

        val auth = SecurityContextHolder.getContext().authentication
        assertNull(auth)
        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `doFilter should not set authentication when header without Bearer prefix`() {
        whenever(request.getHeader("Authorization")).thenReturn("Basic abc123")

        filter.doFilter(request, response, filterChain)

        val auth = SecurityContextHolder.getContext().authentication
        assertNull(auth)
        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `doFilter should always call filterChain`() {
        whenever(request.getHeader("Authorization")).thenReturn(null)

        filter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `doFilter should extract token after Bearer prefix`() {
        whenever(request.getHeader("Authorization")).thenReturn("Bearer my.jwt.token")
        whenever(jwtTokenProvider.validateToken("my.jwt.token")).thenReturn(true)
        whenever(jwtTokenProvider.validateAndGetSubject("my.jwt.token")).thenReturn("subject")

        filter.doFilter(request, response, filterChain)

        verify(jwtTokenProvider).validateToken("my.jwt.token")
        verify(jwtTokenProvider).validateAndGetSubject("my.jwt.token")
    }

    @Test
    fun `doFilter should handle empty Bearer token`() {
        whenever(request.getHeader("Authorization")).thenReturn("Bearer ")

        filter.doFilter(request, response, filterChain)

        val auth = SecurityContextHolder.getContext().authentication
        assertNull(auth)
        verify(filterChain).doFilter(request, response)
    }
}