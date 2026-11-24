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
    fun linkHintIsADigestThatTellsNetworksApartAndCarriesNoAddress() {
        fun address(text: String) = InetAddress.getByName(text)
        val wifi = PlatformNetworkInterface.WIFI
        val home = PlatformLifecycle.linkHint(wifi, listOf(address("192.168.31.1")), listOf(address("192.168.31.1")))!!
        assertTrue(Regex("[0-9a-f]{16}").matches(home))
        assertTrue(!home.contains("192.168") && !home.contains("."))

        // Same network, DNS servers in another order: same hint.
        val ispDns = listOf(address("223.5.5.5"), address("114.114.114.114"))
        assertEquals(
            PlatformLifecycle.linkHint(wifi, listOf(address("10.0.0.1")), ispDns),
            PlatformLifecycle.linkHint(wifi, listOf(address("10.0.0.1")), ispDns.reversed()),
        )
        // Another gateway, other DNS servers, or another kind: another network.
        val other = PlatformLifecycle.linkHint(wifi, listOf(address("192.168.31.2")), listOf(address("192.168.31.1")))
        val otherDns = PlatformLifecycle.linkHint(wifi, listOf(address("192.168.31.1")), listOf(address("8.8.8.8")))
        val ethernet = PlatformLifecycle.linkHint(
            PlatformNetworkInterface.ETHERNET, listOf(address("192.168.31.1")), listOf(address("192.168.31.1")),
        )
        assertEquals(4, setOf(home, other, otherDns, ethernet).size)

        // With an IPv4 gateway the IPv6 routes and servers that arrive later do not change the hint.
        assertEquals(
            home,
            PlatformLifecycle.linkHint(
                wifi,
                listOf(address("192.168.31.1"), address("fe80::1")),
                listOf(address("192.168.31.1"), address("fe80::1")),
            ),
        )
        // IPv6-only: the router's link-local gateway counts.
        val ipv6 = PlatformLifecycle.linkHint(wifi, listOf(address("fe80::1")), emptyList())
        val ipv6Other = PlatformLifecycle.linkHint(wifi, listOf(address("fe80::2")), emptyList())
        assertTrue(ipv6 != null && ipv6 != ipv6Other)

        assertNull(PlatformLifecycle.linkHint(wifi, emptyList(), emptyList()))
        assertNull(PlatformLifecycle.linkHint(wifi, listOf(address("0.0.0.0")), emptyList()))
    }

    /**
     * Fixed vectors of the link hint. The Flutter lifecycle plugin's Android side (`NetworkMonitor.linkHint`)
     * checks the same ones: both must report the same hint for the same network.
     */
    @Test
    fun linkHintMatchesTheSharedVectors() {
        fun address(text: String) = InetAddress.getByName(text)
        val wifi = PlatformNetworkInterface.WIFI
        assertEquals(
            "6dd19d25fa21927d",
            PlatformLifecycle.linkHint(wifi, listOf(address("192.168.31.1")), listOf(address("192.168.31.1"))),
        )
        assertEquals(
            "eb824faf1d5ea988",
            PlatformLifecycle.linkHint(
                wifi,
                listOf(address("10.0.0.1")),
                listOf(address("223.5.5.5"), address("114.114.114.114")),
            ),
        )
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
