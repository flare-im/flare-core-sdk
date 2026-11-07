package com.flare.im.lifecycle

import java.net.InetAddress
import java.util.Collections
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PlatformLifecycleTest {
    private class Reports {
        val network: MutableList<Pair<PlatformNetworkState, String>> = Collections.synchronizedList(mutableListOf())
        val app: MutableList<PlatformAppState> = Collections.synchronizedList(mutableListOf())

        fun await(count: Int) {
            val deadline = System.currentTimeMillis() + 2_000
            while (network.size + app.size < count && System.currentTimeMillis() < deadline) Thread.sleep(5)
        }
    }

    private fun lifecycle(
        reports: Reports,
        network: PlatformNetworkSource,
        appState: PlatformAppStateSource,
        failFirst: Boolean = false,
        onError: (Throwable) -> Unit = {},
    ): PlatformLifecycle {
        var failed = !failFirst
        return PlatformLifecycle(
            notifyNetworkChange = { state, reason ->
                synchronized(reports) {
                    if (!failed) {
                        failed = true
                        reports.network += state to reason
                        error("rejected")
                    }
                }
                reports.network += state to reason
            },
            setAppState = { reports.app += it },
            network = network,
            appState = appState,
            onError = onError,
        )
    }

    /** Install reports the current state once; repeats are dropped, changes go out in order. */
    @Test
    fun reportsTheCurrentStateFirstAndDropsRepeats() {
        val reports = Reports()
        val wifi = PlatformNetworkState(true, PlatformNetworkInterface.WIFI, metered = false, fingerprintHint = "192.168.1.0/24")
        val network = FakeNetworkSource(wifi)
        val appState = FakeAppStateSource(PlatformAppState.FOREGROUND)
        val lifecycle = lifecycle(reports, network, appState).install()

        reports.await(2)
        network.emit(wifi)
        appState.emit(PlatformAppState.FOREGROUND)
        val cellular = PlatformNetworkState(true, PlatformNetworkInterface.CELLULAR, metered = true, fingerprintHint = "46000")
        network.emit(cellular)
        appState.emit(PlatformAppState.BACKGROUND)
        network.emit(PlatformNetworkState(false))
        reports.await(5)
        lifecycle.dispose()

        assertEquals(
            listOf(wifi to "initial", cellular to "network_change", PlatformNetworkState(false) to "network_change"),
            reports.network.toList(),
        )
        assertEquals(listOf(PlatformAppState.FOREGROUND, PlatformAppState.BACKGROUND), reports.app.toList())
    }

    /** Installing twice starts the sources once. */
    @Test
    fun installIsIdempotent() {
        val reports = Reports()
        val network = FakeNetworkSource(PlatformNetworkState(true, PlatformNetworkInterface.WIFI, fingerprintHint = "10.0.0.0/24"))
        val lifecycle = lifecycle(reports, network, FakeAppStateSource(PlatformAppState.BACKGROUND)).install()
        reports.await(2)
        lifecycle.install()
        lifecycle.dispose()
        assertEquals("wifi", reports.network.single().first.interfaceKind?.wireValue)
        assertEquals(listOf(PlatformAppState.BACKGROUND), reports.app.toList())
        assertEquals(1, network.starts)
    }

    @Test
    fun disposeStopsReporting() {
        val reports = Reports()
        val network = FakeNetworkSource(PlatformNetworkState(true, PlatformNetworkInterface.ETHERNET))
        val appState = FakeAppStateSource(null)
        val lifecycle = lifecycle(reports, network, appState).install()
        reports.await(1)

        lifecycle.dispose()
        assertTrue(network.stopped)
        assertTrue(appState.stopped)
        network.emit(PlatformNetworkState(false))
        appState.emit(PlatformAppState.BACKGROUND)
        Thread.sleep(50)
        assertEquals(1, reports.network.size + reports.app.size)
    }

    /** A rejected report goes to onError; the next still goes out. */
    @Test
    fun aRejectedReportDoesNotStopTheNext() {
        val reports = Reports()
        val errors = Collections.synchronizedList(mutableListOf<Throwable>())
        val lifecycle = lifecycle(
            reports,
            FakeNetworkSource(PlatformNetworkState(true, PlatformNetworkInterface.WIFI)),
            FakeAppStateSource(PlatformAppState.FOREGROUND),
            failFirst = true,
            onError = { errors += it },
        ).install()
        reports.await(2)
        lifecycle.dispose()
        assertEquals(1, errors.size)
        assertEquals(listOf(PlatformAppState.FOREGROUND), reports.app.toList())
    }

    @Test
    fun gatewayPrefixIsIpv4SlashTwentyFourElseGlobalIpv6SlashSixtyFour() {
        fun address(text: String) = InetAddress.getByName(text)
        assertEquals("192.168.31.0/24", PlatformLifecycle.gatewayPrefix(listOf(address("192.168.31.1"))))
        assertEquals(
            "10.0.0.0/24",
            PlatformLifecycle.gatewayPrefix(listOf(address("fe80::1"), address("2001:db8:a:b::1"), address("10.0.0.1"))),
        )
        assertEquals("2001:db8:a:b::/64", PlatformLifecycle.gatewayPrefix(listOf(address("2001:db8:a:b::1"))))
        assertNull(PlatformLifecycle.gatewayPrefix(listOf(address("fe80::1"))))
        assertNull(PlatformLifecycle.gatewayPrefix(emptyList()))
    }

    @Test
    fun operatorHintIsTheMccMncOnly() {
        assertEquals("46000", PlatformLifecycle.operatorHint("46000"))
        assertEquals("310260", PlatformLifecycle.operatorHint(" 310260 "))
        assertNull(PlatformLifecycle.operatorHint(""))
        assertNull(PlatformLifecycle.operatorHint(null))
        assertNull(PlatformLifecycle.operatorHint("CMCC"))
    }
}

internal class FakeNetworkSource(private val initial: PlatformNetworkState?) : PlatformNetworkSource {
    @Volatile private var onChange: ((PlatformNetworkState) -> Unit)? = null
    @Volatile var starts = 0
    @Volatile var stopped = false

    override fun start(onChange: (PlatformNetworkState) -> Unit) {
        starts += 1
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
