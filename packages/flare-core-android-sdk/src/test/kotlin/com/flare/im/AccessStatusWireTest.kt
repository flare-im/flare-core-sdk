package com.flare.im

import com.flare.im.adapter.codec.accessStatusFromJson
import com.flare.im.adapter.module.DefaultAccessApi
import com.flare.im.bridge.FlareSdkException
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallDescriptor
import com.flare.im.contract.SdkErrorCodes
import com.flare.im.model.command.AccessImportRecoveryRequest
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** `access.get_status` as the JNI bridge hands it over: plain maps, null for JSON null. */
class AccessStatusWireTest {
    private fun status(
        connectAck: Map<String, Any?>? = null,
        refresh: Map<String, Any?>? = null,
        recovering: Map<String, Any?>? = null,
    ): Map<String, Any?> = mapOf(
        "loaded" to true, "serial" to 42, "source" to "seed", "stale" to false, "developmentMode" to false,
        "issuedAtMs" to null, "expiresAtMs" to null, "fetchedAtMs" to null, "regionId" to "sg",
        "cellId" to "cell-sg-a", "keystateSerial" to null, "accessPointId" to "ap-sg-1", "protocol" to "quic",
        "pinned" to null, "connectAck" to connectAck, "refresh" to refresh, "recovering" to recovering,
    )

    @Test
    fun readsTheConnectAckDiagnostics() {
        val status = accessStatusFromJson(
            status(
                mapOf(
                    "gatewayId" to "gw-7", "accessPointId" to "ap-sg-2", "accessSerial" to 43,
                    "heartbeatIntervalHintSec" to 25, "accessPointMismatch" to true,
                ),
            ),
        )

        val ack = status.connectAck ?: error("no connectAck")
        assertEquals("gw-7", ack.gatewayId)
        assertEquals("ap-sg-2", ack.accessPointId)
        assertEquals(43L, ack.accessSerial)
        assertEquals(25, ack.heartbeatIntervalHintSec)
        assertTrue(ack.accessPointMismatch)
        assertEquals("ap-sg-1", status.accessPointId)
    }

    @Test
    fun keepsAbsentConnectAckFieldsNull() {
        val ack = accessStatusFromJson(
            status(
                mapOf(
                    "gatewayId" to null, "accessPointId" to null, "accessSerial" to null,
                    "heartbeatIntervalHintSec" to null, "accessPointMismatch" to false,
                ),
            ),
        ).connectAck ?: error("no connectAck")

        assertNull(ack.gatewayId)
        assertNull(ack.accessPointId)
        assertNull(ack.accessSerial)
        assertNull(ack.heartbeatIntervalHintSec)
        assertFalse(ack.accessPointMismatch)
    }

    @Test
    fun hasNoConnectAckWithoutAConnection() {
        assertNull(accessStatusFromJson(status(null)).connectAck)
    }

    @Test
    fun readsTheManifestTimesRefreshProgressAndRecovery() {
        val status = accessStatusFromJson(
            status(
                refresh = mapOf(
                    "lastAttemptAtMs" to 1_793_779_260_000L, "lastSuccessAtMs" to 1_793_779_200_000L,
                    "lastOutcome" to "adopted", "nextAtMs" to 1_793_800_860_000L,
                ),
                recovering = mapOf(
                    "sinceMs" to 1_793_779_000_000L, "rounds" to 2, "nextRoundAtMs" to 1_793_779_090_000L,
                ),
            ) + mapOf(
                "issuedAtMs" to 1_793_779_200_000L, "expiresAtMs" to 1_796_371_200_000L,
                "fetchedAtMs" to 1_793_779_260_000L,
            ),
        )

        assertEquals(1_793_779_200_000L, status.issuedAtMs)
        assertEquals(1_796_371_200_000L, status.expiresAtMs)
        assertEquals(1_793_779_260_000L, status.fetchedAtMs)
        val refresh = status.refresh ?: error("no refresh")
        assertEquals(1_793_779_260_000L, refresh.lastAttemptAtMs)
        assertEquals(1_793_779_200_000L, refresh.lastSuccessAtMs)
        assertEquals("adopted", refresh.lastOutcome)
        assertEquals(1_793_800_860_000L, refresh.nextAtMs)
        val recovering = status.recovering ?: error("no recovering")
        assertEquals(1_793_779_000_000L, recovering.sinceMs)
        assertEquals(2, recovering.rounds)
        assertEquals(1_793_779_090_000L, recovering.nextRoundAtMs)
    }

    @Test
    fun keepsAbsentRefreshAndRecoveryFieldsNull() {
        val status = accessStatusFromJson(
            status(
                refresh = mapOf(
                    "lastAttemptAtMs" to null, "lastSuccessAtMs" to null, "lastOutcome" to null, "nextAtMs" to null,
                ),
                recovering = mapOf("sinceMs" to 5, "rounds" to 0, "nextRoundAtMs" to null),
            ),
        )

        assertNull(status.issuedAtMs)
        assertNull(status.fetchedAtMs)
        assertNull(status.refresh?.lastOutcome)
        assertNull(status.refresh?.nextAtMs)
        assertNull(status.recovering?.nextRoundAtMs)
        assertNull(accessStatusFromJson(status()).refresh)
        assertNull(accessStatusFromJson(status()).recovering)
    }

    @Test
    fun refreshReportsEverySourceItTried() = runBlocking {
        val bridge = AnswerBridge(
            "access.refresh" to mapOf(
                "outcome" to "adopted", "mode" to "background", "serial" to 42,
                "source" to "https:https://cfg-b/", "keystateSerial" to 3,
                "attempts" to listOf(
                    mapOf(
                        "source" to "https:https://cfg-a/", "tier" to "mirror", "document" to "access",
                        "result" to "failed", "code" to "timeout", "serial" to null,
                    ),
                    mapOf(
                        "source" to "https:https://cfg-b/", "tier" to "mirror", "document" to "access",
                        "result" to "adopted", "code" to null, "serial" to 42,
                    ),
                ),
            ),
        )

        val report = DefaultAccessApi(bridge).refresh()

        assertEquals(listOf("access.refresh"), bridge.operations)
        assertEquals("adopted", report.outcome)
        assertEquals("background", report.mode)
        assertEquals(42L, report.serial)
        assertEquals("https:https://cfg-b/", report.source)
        assertEquals(3L, report.keystateSerial)
        assertEquals(listOf("failed", "adopted"), report.attempts.map { it.result })
        assertEquals("timeout", report.attempts.first().code)
        assertNull(report.attempts.first().serial)
        assertNull(report.attempts.last().code)
        assertEquals(42L, report.attempts.last().serial)
    }

    @Test
    fun aRefreshWithoutAttemptsIsRefused() {
        val bridge = AnswerBridge(
            "access.refresh" to mapOf("outcome" to "failed", "mode" to "background", "serial" to 0),
        )

        val error = assertThrows(FlareSdkException::class.java) {
            runBlocking { DefaultAccessApi(bridge).refresh() }
        }

        assertEquals(SdkErrorCodes.INVALIDPARAMETER, error.code)
    }

    @Test
    fun aRecoveryLinkGoesVerbatimAndABadOneIsAnAnswer() = runBlocking {
        val link = "flare-recover://v1?p=abc&k=root-a&s=def"
        val bridge = AnswerBridge(
            "access.import_recovery" to mapOf("outcome" to "rejected", "code" to "rollback", "serial" to 42),
        )

        val imported = DefaultAccessApi(bridge).importRecovery(AccessImportRecoveryRequest(link = link))

        assertEquals(listOf("access.import_recovery"), bridge.operations)
        assertEquals(mapOf("link" to link), bridge.requests.single())
        assertEquals("rejected", imported.outcome)
        assertEquals("rollback", imported.code)
        assertEquals(42L, imported.serial)
    }

    @Test
    fun anAdoptedRecoveryLinkHasNoCode() = runBlocking {
        val bridge = AnswerBridge(
            "access.import_recovery" to mapOf("outcome" to "adopted", "code" to null, "serial" to 2000),
        )

        val imported = DefaultAccessApi(bridge).importRecovery(
            AccessImportRecoveryRequest(link = "flare-recover://v1?p=a&k=b&s=c"),
        )

        assertEquals("adopted", imported.outcome)
        assertNull(imported.code)
        assertEquals(2000L, imported.serial)
    }

    /** Answers each operation with plain maps, the way the JNI bridge hands them over. */
    private class AnswerBridge(vararg answers: Pair<String, Any?>) : NativeBridge {
        private val answers = mapOf(*answers)
        val operations = mutableListOf<String>()
        val requests = mutableListOf<Any?>()

        override suspend fun <T> invoke(descriptor: NativeCallDescriptor, request: Any?): T {
            operations += descriptor.operation
            requests += request
            @Suppress("UNCHECKED_CAST")
            return answers[descriptor.operation] as T
        }
    }
}
