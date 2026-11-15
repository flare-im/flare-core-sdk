package com.flare.im.lifecycle

import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkMonitorTest {
    private fun address(text: String) = InetAddress.getByName(text)

    /**
     * The same fixed vectors as the native module's `PlatformLifecycleTest.linkHintMatchesTheSharedVectors`:
     * a Flutter app and a native app report the same hint for the same network.
     */
    @Test
    fun linkHintMatchesTheNativeModule() {
        assertEquals(
            "6dd19d25fa21927d",
            NetworkMonitor.linkHint("wifi", listOf(address("192.168.31.1")), listOf(address("192.168.31.1"))),
        )
        assertEquals(
            "eb824faf1d5ea988",
            NetworkMonitor.linkHint(
                "wifi",
                listOf(address("10.0.0.1")),
                listOf(address("223.5.5.5"), address("114.114.114.114")),
            ),
        )
    }

    @Test
    fun linkHintIsADigestThatTellsNetworksApartAndCarriesNoAddress() {
        val home = NetworkMonitor.linkHint("wifi", listOf(address("192.168.31.1")), listOf(address("192.168.31.1")))!!
        assertTrue(Regex("[0-9a-f]{16}").matches(home))
        assertTrue(!home.contains("192.168") && !home.contains("."))

        // Same network, DNS servers in another order: same hint.
        val ispDns = listOf(address("223.5.5.5"), address("114.114.114.114"))
        assertEquals(
            NetworkMonitor.linkHint("wifi", listOf(address("10.0.0.1")), ispDns),
            NetworkMonitor.linkHint("wifi", listOf(address("10.0.0.1")), ispDns.reversed()),
        )
        // Another gateway, other DNS servers, or another kind: another network.
        val other = NetworkMonitor.linkHint("wifi", listOf(address("192.168.31.2")), listOf(address("192.168.31.1")))
        val otherDns = NetworkMonitor.linkHint("wifi", listOf(address("192.168.31.1")), listOf(address("8.8.8.8")))
        val ethernet =
            NetworkMonitor.linkHint("ethernet", listOf(address("192.168.31.1")), listOf(address("192.168.31.1")))
        assertEquals(4, setOf(home, other, otherDns, ethernet).size)

        // With an IPv4 gateway the IPv6 routes and servers that arrive later do not change the hint.
        assertEquals(
            home,
            NetworkMonitor.linkHint(
                "wifi",
                listOf(address("192.168.31.1"), address("fe80::1")),
                listOf(address("192.168.31.1"), address("fe80::1")),
            ),
        )
        // IPv6-only: the router's link-local gateway counts.
        val ipv6 = NetworkMonitor.linkHint("wifi", listOf(address("fe80::1")), emptyList())
        val ipv6Other = NetworkMonitor.linkHint("wifi", listOf(address("fe80::2")), emptyList())
        assertTrue(ipv6 != null && ipv6 != ipv6Other)

        assertNull(NetworkMonitor.linkHint("wifi", emptyList(), emptyList()))
        assertNull(NetworkMonitor.linkHint("wifi", listOf(address("0.0.0.0")), emptyList()))
    }

    @Test
    fun operatorHintIsTheMccMncDigits() {
        assertEquals("46001", NetworkMonitor.operatorHint(" 46001 "))
        assertEquals("310260", NetworkMonitor.operatorHint("310260"))
        assertNull(NetworkMonitor.operatorHint(""))
        assertNull(NetworkMonitor.operatorHint("460-01"))
        assertNull(NetworkMonitor.operatorHint(null))
    }
}
