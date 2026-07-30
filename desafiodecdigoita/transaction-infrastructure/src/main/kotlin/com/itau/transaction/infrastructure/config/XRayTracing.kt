package com.itau.transaction.infrastructure.config

import com.amazonaws.xray.AWSXRay
import org.slf4j.LoggerFactory

/**
 * Helper functions for AWS X-Ray distributed tracing.
 * Creates subsegments for custom operations.
 */
object XRayTracing {

    private val log = LoggerFactory.getLogger(XRayTracing::class.java)

    /**
     * Executes [block] inside an X-Ray subsegment with the given [name].
     * If X-Ray is not active (no segment), executes the block without tracing.
     */
    fun <T> trace(name: String, block: () -> T): T {
        val segment = AWSXRay.getCurrentSegment()
        if (segment == null) {
            log.trace("No active X-Ray segment, skipping subsegment: {}", name)
            return block()
        }

        val subsegment = AWSXRay.beginSubsegment(name)
        return try {
            block()
        } catch (e: Exception) {
            if (subsegment != null) {
                subsegment.addException(e)
            }
            throw e
        } finally {
            if (subsegment != null) {
                AWSXRay.endSubsegment()
            }
        }
    }
}