package com.flare.im

import com.flare.im.adapter.DefaultFlareImClient
import com.flare.im.adapter.module.DefaultConnectionApi
import com.flare.im.adapter.module.DefaultLifecycleApi
import com.flare.im.lifecycle.PlatformAppState
import com.flare.im.lifecycle.PlatformAppStateSource
import com.flare.im.lifecycle.PlatformLifecycle
import com.flare.im.lifecycle.PlatformNetworkInterface
import com.flare.im.lifecycle.PlatformNetworkSource
import com.flare.im.lifecycle.PlatformNetworkState
import com.flare.im.lifecycle.forClient
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/** The core client's wiring of [PlatformLifecycle]; its own behaviour is tested in flare-core-android-lifecycle. */
class ClientPlatformLifecycleTest {
    /** forClient puts the reports on the wire as `connection.notify_network_change` and `lifecycle.set_app_state`. */
    @Test
    fun forClientReportsThroughTheConnectionAndLifecycleApis() {
        val bridge = RecordingBridge()
        val wifi = PlatformNetworkState(true, PlatformNetworkInterface.WIFI, metered = false, fingerprintHint = "192.168.1.0/24")
        val network = FakeNetworkSource(wifi)
        val appState = FakeAppStateSource(PlatformAppState.FOREGROUND)
        val lifecycle = PlatformLifecycle.forClient(
            DefaultConnectionApi(bridge),
            DefaultLifecycleApi(bridge),
            network,
            appState,
        ).install()

        bridge.awaitCalls(2)
        network.emit(wifi)
        appState.emit(PlatformAppState.FOREGROUND)
        network.emit(PlatformNetworkState(true, PlatformNetworkInterface.CELLULAR, metered = true, fingerprintHint = "46000"))
        appState.emit(PlatformAppState.BACKGROUND)
        network.emit(PlatformNetworkState(false))
        bridge.awaitCalls(5)
        lifecycle.dispose()

        val networkCalls = bridge.calls.filter { it.operation == "connection.notify_network_change" }
        val appCalls = bridge.calls.filter { it.operation == "lifecycle.set_app_state" }
        assertEquals(3, networkCalls.size)
        assertEquals(2, appCalls.size)
        val first = networkCalls[0].request
        assertEquals(true, first["available"])
        assertEquals("wifi", first["interface"])
        assertEquals("192.168.1.0/24", first["fingerprintHint"])
        assertEquals("initial", first["reason"])
        assertEquals("cellular", networkCalls[1].request["interface"])
        assertEquals("46000", networkCalls[1].request["fingerprintHint"])
        assertEquals("network_change", networkCalls[1].request["reason"])
        assertEquals(false, networkCalls[2].request["available"])
        assertEquals(listOf("foreground", "background"), appCalls.map { it.request["appState"] })
    }

    /** The client installs after a successful init, strips the switch, and disposes on dispose. */
    @Test
    fun theClientInstallsAfterInitAndDisposeRemovesIt() = runBlocking {
        val bridge = RecordingBridge()
        val built = mutableListOf<FakeNetworkSource>()
        val client = DefaultFlareImClient(bridge) { connection, lifecycle ->
            val network = FakeNetworkSource(null).also { built += it }
            PlatformLifecycle.forClient(connection, lifecycle, network, FakeAppStateSource(null))
        }

        client.init(mapOf("tenantId" to "0"))
        assertEquals(1, built.size)
        assertFalse(built[0].stopped)
        assertTrue(built[0].started)

        client.dispose()
        assertTrue(built[0].stopped)
    }

    @Test
    fun installPlatformLifecycleFalseLeavesItOut() = runBlocking {
        val bridge = RecordingBridge()
        var built = 0
        val client = DefaultFlareImClient(bridge) { connection, lifecycle ->
            built += 1
            PlatformLifecycle.forClient(connection, lifecycle, FakeNetworkSource(null), FakeAppStateSource(null))
        }

        client.init(mapOf("tenantId" to "0", "installPlatformLifecycle" to false))

        assertEquals(0, built)
        val init = bridge.calls.single { it.operation == "sdk.init" }
        assertFalse(init.request.containsKey("installPlatformLifecycle"))
        assertEquals("0", init.request["tenantId"])
    }

    @Test
    fun aFailedInitInstallsNothing() = runBlocking {
        val bridge = RecordingBridge(failFirst = true)
        var built = 0
        val client = DefaultFlareImClient(bridge) { connection, lifecycle ->
            built += 1
            PlatformLifecycle.forClient(connection, lifecycle, FakeNetworkSource(null), FakeAppStateSource(null))
        }
        try {
            client.init(mapOf("tenantId" to "0"))
            fail("init should fail")
        } catch (_: Exception) {
        }
        assertEquals(0, built)
    }
}

internal class FakeNetworkSource(private val initial: PlatformNetworkState?) : PlatformNetworkSource {
    @Volatile private var onChange: ((PlatformNetworkState) -> Unit)? = null
    @Volatile var starts = 0
    @Volatile var started = false
    @Volatile var stopped = false

    override fun start(onChange: (PlatformNetworkState) -> Unit) {
        starts += 1
        started = true
        this.onChange = onChange
        initial?.let(onChange)
    }

    override fun stop() {
        stopped = true
    }

    fun emit(state: PlatformNetworkState) {
        onChange?.invoke(state)
    }
}

internal class FakeAppStateSource(private val initial: PlatformAppState?) : PlatformAppStateSource {
    @Volatile private var onChange: ((PlatformAppState) -> Unit)? = null
    @Volatile var stopped = false

    override fun start(onChange: (PlatformAppState) -> Unit) {
        this.onChange = onChange
        initial?.let(onChange)
    }

    override fun stop() {
        stopped = true
    }

    fun emit(state: PlatformAppState) {
        onChange?.invoke(state)
    }
}
