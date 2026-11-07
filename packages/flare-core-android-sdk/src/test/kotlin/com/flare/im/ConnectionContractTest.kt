package com.flare.im

import com.flare.im.adapter.DefaultFlareImClient
import com.flare.im.adapter.module.DefaultEventsApi
import com.flare.im.bridge.ConnectTokenRefreshRouter
import com.flare.im.bridge.FlareAppInfo
import com.flare.im.bridge.FlareSdkException
import com.flare.im.bridge.NetworkUncertainException
import com.flare.im.bridge.OverloadedException
import com.flare.im.bridge.UpgradeRequiredException
import com.flare.im.contract.ConnectTokenRefresher
import com.flare.im.contract.SdkErrorCodes
import com.flare.im.listener.FlareImEventListener
import com.flare.im.model.entity.ConnectionPhase
import com.flare.im.model.entity.ConnectionQuality
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.model.event.EventCode
import com.flare.im.model.event.access.AccessChangedEvent
import com.flare.im.model.event.access.AccessSwitchedEvent
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class ConnectionContractTest {
    // connection://status and access events

    /** The C ABI event: every field present, null without a value, plus `type` / `event`. */
    @Test
    fun connectionStatusEventDecodesWithNulls() {
        val events = DefaultEventsApi(RecordingBridge())
        var status: ConnectionStatus? = null
        events.onConnectionStatusChanged { status = it }

        events.emitNativeEvent(
            EventCode.CONNECTION_STATUS,
            mapOf(
                "type" to "connection", "event" to "status", "phase" to "reconnecting", "quality" to null,
                "accessPointId" to "ap-sg-1", "cellId" to "cell-sg-a", "regionId" to "sg", "protocol" to "quic",
                "rttMs" to null, "attempt" to 2, "nextRetryAt" to 1_762_250_000_000L, "reason" to null,
                "developmentMode" to false,
            ),
        )

        val decoded = status ?: error("no status")
        assertEquals(ConnectionPhase.RECONNECTING, decoded.phase)
        assertNull(decoded.quality)
        assertEquals("ap-sg-1", decoded.accessPointId)
        assertEquals("cell-sg-a", decoded.cellId)
        assertEquals("sg", decoded.regionId)
        assertEquals("quic", decoded.protocol)
        assertNull(decoded.rttMs)
        assertEquals(2, decoded.attempt)
        assertEquals(1_762_250_000_000L, decoded.nextRetryAt)
        assertNull(decoded.reason)
        assertFalse(decoded.developmentMode)
    }

    @Test
    fun onlineAndWaitingStatusesReachTheListener() {
        val events = DefaultEventsApi(RecordingBridge())
        val seen = mutableListOf<ConnectionStatus>()
        events.addEventListener(object : FlareImEventListener {
            override fun onConnectionStatusChanged(event: ConnectionStatus) {
                seen += event
            }
        })

        events.emitNativeEvent(EventCode.CONNECTION_STATUS, status("online", quality = "poor", rttMs = 412, developmentMode = true))
        events.emitNativeEvent(EventCode.CONNECTION_STATUS, status("waitingForNetwork"))
        events.emitNativeEvent(EventCode.CONNECTION_STATUS, status("actionRequired", reason = "upgradeRequired"))

        assertEquals(
            listOf(ConnectionPhase.ONLINE, ConnectionPhase.WAITING_FOR_NETWORK, ConnectionPhase.ACTION_REQUIRED),
            seen.map { it.phase },
        )
        assertEquals(ConnectionQuality.POOR, seen[0].quality)
        assertEquals(412, seen[0].rttMs)
        assertTrue(seen[0].developmentMode)
        assertEquals("upgradeRequired", seen[2].reason)
    }

    @Test
    fun accessEventsDecode() {
        val events = DefaultEventsApi(RecordingBridge())
        var switched: AccessSwitchedEvent? = null
        var changed: AccessChangedEvent? = null
        events.onAccessSwitched { switched = it }
        events.onAccessChanged { changed = it }

        events.emitNativeEvent(
            EventCode.ACCESS_SWITCHED,
            mapOf(
                "from" to mapOf("ap" to "ap-sg-1", "protocol" to "quic"),
                "to" to mapOf("ap" to "ap-sg-2", "protocol" to "ws"),
                "reason" to "failure",
            ),
        )
        events.emitNativeEvent(
            EventCode.ACCESS_CHANGED,
            mapOf(
                "serial" to 42, "source" to "lkg", "stale" to false, "developmentMode" to false,
                "changes" to mapOf(
                    "accessPointsAdded" to listOf("ap-sg-3"),
                    "accessPointsRemoved" to emptyList<String>(),
                    "policyChanged" to true,
                ),
            ),
        )

        assertEquals("ap-sg-1", switched?.from?.ap)
        assertEquals("ws", switched?.to?.protocol)
        assertEquals("failure", switched?.reason)
        assertEquals(42L, changed?.serial)
        assertEquals("lkg", changed?.source)
        assertEquals(listOf("ap-sg-3"), changed?.changes?.accessPointsAdded)
        assertEquals(true, changed?.changes?.policyChanged)
    }

    // typed errors

    @Test
    fun typedErrorsFromTheCAbiCode() {
        val overloaded = FlareSdkException.fromNative(12, "busy", null, null)
        assertTrue(overloaded is OverloadedException)
        assertEquals("OVERLOADED", overloaded.code)
        assertNull((overloaded as OverloadedException).retryAfterMs)
        assertTrue(FlareSdkException.fromNative(13, "old", null, "") is UpgradeRequiredException)
        assertTrue(FlareSdkException.fromNative(14, "unknown", null, null) is NetworkUncertainException)
        val other = FlareSdkException.fromNative(5, "down", null, null)
        assertFalse(other is OverloadedException || other is UpgradeRequiredException || other is NetworkUncertainException)
        assertEquals("native.5", other.code)
    }

    @Test
    fun typedErrorsFromTheStructuredCode() {
        val overloaded = FlareSdkException.fromNative(
            12, "busy", "connection.reconnect_now",
            """{"code":"OVERLOADED","reason":"sdk.overloaded","retryable":true,"retryAfterMs":1500}""",
        )
        assertTrue(overloaded is OverloadedException)
        assertEquals(1500L, (overloaded as OverloadedException).retryAfterMs)
        assertTrue(overloaded.retryable)
        assertEquals("connection.reconnect_now", overloaded.operation)
        assertTrue(
            FlareSdkException.fromNative(13, "old", null, """{"code":"UPGRADE_REQUIRED"}""") is UpgradeRequiredException,
        )
        assertTrue(FlareSdkException.create(SdkErrorCodes.NETWORKUNCERTAIN, "unknown") is NetworkUncertainException)
    }

    // connect token refresher

    @Test
    fun tokenRequestRoundTrip() {
        val router = ConnectTokenRefreshRouter()
        val answers = Answers()
        router.install(7, { "token-2" }, answers::add)

        router.request(7, 42)

        assertEquals(listOf(42L to "token-2"), answers.await(1))
    }

    @Test
    fun aThrowingOrBlankRefresherAnswersNone() {
        val router = ConnectTokenRefreshRouter()
        val answers = Answers()
        router.install(7, { throw IllegalStateException("no session") }, answers::add)
        router.install(8, { " " }, answers::add)
        router.install(9, { null }, answers::add)

        router.request(7, 1)
        router.request(8, 2)
        router.request(9, 3)

        val got = answers.await(3)
        assertEquals(setOf(1L, 2L, 3L), got.map { it.first }.toSet())
        assertTrue(got.all { it.second == null })
    }

    @Test
    fun aSlowRefresherIsAnsweredNoneAtTheDeadline() {
        val router = ConnectTokenRefreshRouter(timeoutMillis = 50)
        val answers = Answers()
        router.install(7, {
            delay(5_000)
            "late"
        }, answers::add)

        router.request(7, 3)

        assertEquals(listOf(3L to null), answers.await(1))
        Thread.sleep(100)
        assertEquals("answered once", 1, answers.all.size)
    }

    @Test
    fun aRemovedRefresherIsNotCalled() {
        val router = ConnectTokenRefreshRouter()
        val answers = Answers()
        router.install(7, { "token" }, answers::add)
        router.remove(7)

        router.request(7, 4)
        Thread.sleep(50)
        assertTrue(answers.all.isEmpty())
    }

    /** The client hands the host function to the bridge hook; null removes it. */
    @Test
    fun theClientHandsTheRefresherToTheBridge() = runBlocking {
        val bridge = RefresherBridge()
        val client = DefaultFlareImClient(bridge)

        client.setConnectTokenRefresher { "token-3" }
        val refresher = bridge.refresher
        assertNotNull(refresher)
        assertEquals("token-3", refresher!!.invoke())

        client.setConnectTokenRefresher(null)
        assertNull(bridge.refresher)
        assertEquals(2, bridge.calls)
    }

    /** A bridge without a refresh channel (a test double) reports capabilityUnavailable. */
    @Test
    fun aBridgeWithoutTheHookReportsCapabilityUnavailable() = runBlocking {
        val client = DefaultFlareImClient(RecordingBridge())
        try {
            client.setConnectTokenRefresher { null }
            fail("expected capabilityUnavailable")
        } catch (error: FlareSdkException) {
            assertEquals(SdkErrorCodes.CAPABILITYUNAVAILABLE, error.code)
        }
    }

    // app info

    @Test
    fun appInfoFillsMissingKeysOfTheAppObject() {
        val collected = FlareAppInfo(appVersion = "3.2.1", appBuild = 30201, distribution = "play", locale = "zh-Hant-TW")

        val channelOnly = collected.fill(mapOf("app" to mapOf("channel" to "stable")))
        @Suppress("UNCHECKED_CAST")
        val app = channelOnly["app"] as Map<String, Any?>
        assertEquals("stable", app["channel"])
        assertEquals("3.2.1", app["version"])
        assertEquals(30201L, app["build"])
        assertEquals("play", app["distribution"])
        assertEquals("zh-Hant-TW", app["locale"])

        val explicitLocale = collected.fill(mapOf("app" to mapOf("locale" to "en")))
        @Suppress("UNCHECKED_CAST")
        assertEquals("en", (explicitLocale["app"] as Map<String, Any?>)["locale"])

        val wrapped = collected.fill(mapOf("environment" to "production", "sdkConfig" to mapOf("app" to mapOf("version" to "3.2.1-hotfix"))))
        @Suppress("UNCHECKED_CAST")
        val wrappedApp = (wrapped["sdkConfig"] as Map<String, Any?>)["app"] as Map<String, Any?>
        assertEquals("3.2.1-hotfix", wrappedApp["version"])
        assertEquals(30201L, wrappedApp["build"])
        assertNull(wrapped["app"])

        assertNull(FlareAppInfo().fill(mapOf("tenantId" to "0"))["app"])
    }

    @Test
    fun distributionComesFromTheInstallSource() {
        assertEquals("play", FlareAppInfo.distributionOf("com.android.vending"))
        assertEquals("appgallery", FlareAppInfo.distributionOf("com.huawei.appmarket"))
        assertEquals("direct", FlareAppInfo.distributionOf("com.google.android.packageinstaller"))
        assertNull(FlareAppInfo.distributionOf("com.xiaomi.market"))
        assertNull(FlareAppInfo.distributionOf("com.android.shell"))
        assertNull(FlareAppInfo.distributionOf(null))
    }

    private fun status(
        phase: String,
        quality: String? = null,
        rttMs: Int? = null,
        reason: String? = null,
        developmentMode: Boolean = false,
    ): Map<String, Any?> = mapOf(
        "phase" to phase, "quality" to quality, "accessPointId" to null, "cellId" to null, "regionId" to null,
        "protocol" to null, "rttMs" to rttMs, "attempt" to 0, "nextRetryAt" to null, "reason" to reason,
        "developmentMode" to developmentMode,
    )
}

private class Answers {
    private val recorded = mutableListOf<Pair<Long, String?>>()

    val all: List<Pair<Long, String?>>
        get() = synchronized(recorded) { recorded.toList() }

    fun add(requestId: Long, token: String?) {
        synchronized(recorded) { recorded += requestId to token }
    }

    fun await(count: Int, timeoutMillis: Long = 2_000): List<Pair<Long, String?>> {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (all.size < count) {
            if (System.currentTimeMillis() > deadline) fail("expected $count answers, got ${all.size}")
            Thread.sleep(5)
        }
        return all
    }
}

/** Keeps the refresher the client hands over. */
private class RefresherBridge : com.flare.im.contract.NativeBridge {
    var refresher: ConnectTokenRefresher? = null
    var calls = 0

    override suspend fun <T> invoke(descriptor: com.flare.im.contract.NativeCallDescriptor, request: Any?): T {
        @Suppress("UNCHECKED_CAST")
        return null as T
    }

    override suspend fun setConnectTokenRefresher(refresher: ConnectTokenRefresher?) {
        this.refresher = refresher
        calls += 1
    }
}
