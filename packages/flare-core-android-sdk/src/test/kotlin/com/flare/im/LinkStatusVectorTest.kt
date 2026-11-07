package com.flare.im

import com.flare.im.adapter.codec.connectionPhaseWireValue
import com.flare.im.adapter.codec.connectionQualityWireValue
import com.flare.im.adapter.codec.connectionStatusFromJson
import com.flare.im.adapter.module.DefaultEventsApi
import com.flare.im.bridge.FlareSdkException
import com.flare.im.contract.SdkErrorCodes
import com.flare.im.model.entity.ConnectionPhase
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.model.event.EventCode
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The engine's link status vectors (`flare-core-sdk-engine/tests/vectors/link_status.json`): each case's
 * `expected` is a `connection://status` payload exactly as the core puts it on the wire. Every platform
 * package decodes the same file.
 */
class LinkStatusVectorTest {
    private data class Vector(val name: String, val expected: Map<String, Any?>)

    private val fields = setOf(
        "phase", "quality", "accessPointId", "cellId", "regionId", "protocol",
        "rttMs", "attempt", "nextRetryAt", "reason", "developmentMode",
    )

    private val vectors: List<Vector> by lazy {
        val table = JSONObject(vectorFile().readText())
        val cases = table.getJSONArray("cases")
        List(cases.length()) { index ->
            val case = cases.getJSONObject(index)
            @Suppress("UNCHECKED_CAST")
            Vector(case.getString("name"), plain(case.getJSONObject("expected")) as Map<String, Any?>)
        }
    }

    @Test
    fun vectorsCoverEveryPublicPhase() {
        assertTrue("the shared vectors lost cases", vectors.size >= 22)
        assertEquals(
            ConnectionPhase.entries.map(::connectionPhaseWireValue).toSet(),
            vectors.map { it.expected["phase"] }.toSet(),
        )
        vectors.forEach { assertEquals(it.name, fields, it.expected.keys) }
    }

    @Test
    fun everyVectorDecodes() {
        vectors.forEach { assertEquals(it.name, it.expected, asWire(connectionStatusFromJson(it.expected))) }
    }

    @Test
    fun everyVectorReachesTheStatusListener() {
        vectors.forEach { vector ->
            val events = DefaultEventsApi(RecordingBridge())
            val delivered = mutableListOf<ConnectionStatus>()
            events.onConnectionStatusChanged { delivered += it }

            events.emitNativeEvent(
                EventCode.CONNECTION_STATUS,
                mapOf("type" to "connection", "event" to "status") + vector.expected,
            )

            assertEquals(vector.name, listOf(vector.expected), delivered.map(::asWire))
        }
    }

    @Test
    fun unknownPhaseIsRejectedNotGuessed() {
        val unknown = vectors.first().expected + ("phase" to "halfOpen")

        val error = assertThrows(FlareSdkException::class.java) { connectionStatusFromJson(unknown) }
        assertEquals(SdkErrorCodes.INVALIDPARAMETER, error.code)

        val events = DefaultEventsApi(RecordingBridge())
        val delivered = mutableListOf<ConnectionStatus>()
        events.onConnectionStatusChanged { delivered += it }
        assertThrows(FlareSdkException::class.java) {
            events.emitNativeEvent(EventCode.CONNECTION_STATUS, unknown)
        }
        assertTrue(delivered.isEmpty())
    }

    /** The decoded status back as wire values (JSON numbers as org.json reads them), to compare field by field. */
    private fun asWire(status: ConnectionStatus): Map<String, Any?> = mapOf(
        "phase" to connectionPhaseWireValue(status.phase),
        "quality" to status.quality?.let(::connectionQualityWireValue),
        "accessPointId" to status.accessPointId,
        "cellId" to status.cellId,
        "regionId" to status.regionId,
        "protocol" to status.protocol,
        "rttMs" to status.rttMs,
        "attempt" to status.attempt,
        "nextRetryAt" to status.nextRetryAt,
        "reason" to status.reason,
        "developmentMode" to status.developmentMode,
    )

    /** JSON as the JNI bridge hands it to the adapter: maps, lists and plain values, null for JSON null. */
    private fun plain(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { plain(value.get(it)) }
        is JSONArray -> List(value.length()) { plain(value.get(it)) }
        else -> value
    }

    private fun vectorFile(): File {
        val relative = "flare-core-sdk-engine/tests/vectors/link_status.json"
        var dir: File? = File(".").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate
            dir = dir.parentFile
        }
        error("$relative not found above ${File(".").absolutePath}")
    }
}
