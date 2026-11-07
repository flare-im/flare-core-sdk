package com.flare.im

import com.flare.im.bridge.FlareSdkException
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallDescriptor
import org.junit.Assert.fail

/** Records every bridge call with its request; can reject the first one. */
internal class RecordingBridge(failFirst: Boolean = false) : NativeBridge {
    data class Call(val operation: String, val request: Map<String, Any?>)

    private val recorded = mutableListOf<Call>()
    private var failNext = failFirst

    val calls: List<Call>
        get() = synchronized(recorded) { recorded.toList() }

    override suspend fun <T> invoke(descriptor: NativeCallDescriptor, request: Any?): T {
        val fail = synchronized(recorded) {
            @Suppress("UNCHECKED_CAST")
            recorded += Call(descriptor.operation, (request as? Map<String, Any?>).orEmpty())
            failNext.also { failNext = false }
        }
        if (fail) {
            throw FlareSdkException("NOT_CONNECTED", "rejected", operation = descriptor.operation)
        }
        @Suppress("UNCHECKED_CAST")
        return null as T
    }

    fun awaitCalls(count: Int, timeoutMillis: Long = 2_000) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (calls.size < count) {
            if (System.currentTimeMillis() > deadline) fail("expected $count bridge calls, got ${calls.size}")
            Thread.sleep(5)
        }
    }
}
