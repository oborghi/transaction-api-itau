package com.itau.transaction.infrastructure.config

import com.amazonaws.xray.AWSXRay
import com.amazonaws.xray.entities.Segment
import org.slf4j.LoggerFactory

/**
 * Helper functions for AWS X-Ray distributed tracing.
 *
 * For background tasks (SQS consumer, DLQ reprocessor, scheduler) that run outside
 * HTTP request context, use [traceBackground] to create a root segment so the
 * AWS SDK v2 interceptor (which auto-creates subsegments for SQS calls) has a
 * parent segment to attach to.
 *
 * For HTTP request-scoped operations, use [trace] which creates a subsegment
 * under the existing HTTP segment created by the servlet filter.
 */
object XRayTracing {

    private val log = LoggerFactory.getLogger(XRayTracing::class.java)

    /**
     * Creates a root segment for background tasks (SQS, schedulers).
     * This ensures the AWS SDK v2 interceptor has a parent segment to attach
     * subsegments to (e.g., "Sqs" subsegments for SQS API calls).
     */
    fun <T> traceBackground(name: String, block: () -> T): T {
        val segment = AWSXRay.beginSegment(name)
        return try {
            block()
        } catch (e: Exception) {
            segment.addException(e)
            throw e
        } finally {
            AWSXRay.endSegment()
        }
    }

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
