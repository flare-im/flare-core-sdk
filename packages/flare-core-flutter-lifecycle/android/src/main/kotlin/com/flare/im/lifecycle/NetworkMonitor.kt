package com.flare.im.lifecycle

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import java.net.Inet4Address
import java.net.InetAddress
import java.security.MessageDigest

/**
 * Follows the default network with `registerDefaultNetworkCallback` and hands every reading to
 * [emit]: `{available, interface, metered, fingerprintHint}`, the current network first.
 *
 * Duplicates are fine: the Dart side reports only changes. Needs `ACCESS_NETWORK_STATE` and
 * nothing else. The fingerprint hint is the one the native Android lifecycle module
 * (`flare-core-android-lifecycle`) reports, by the same algorithm: a digest of the link for Wi-Fi,
 * Ethernet and other links ([linkHint]), the operator's MCC-MNC for cellular ([operatorHint]).
 * Never an SSID, a BSSID or a raw address.
 */
internal class NetworkMonitor(
    context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val telephony = context.getSystemService(TelephonyManager::class.java)
    private var callback: ConnectivityManager.NetworkCallback? = null

    /** The network the readings currently describe. */
    @Volatile
    private var current: Network? = null

    fun start() {
        val manager = connectivity ?: run {
            emit(unavailable())
            return
        }
        val active = manager.activeNetwork
        current = active
        emit(read(active, null))
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                current = network
                emit(read(network, null))
            }

            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                current = network
                emit(read(network, capabilities))
            }

            override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
                current = network
                emit(read(network, null, linkProperties))
            }

            override fun onLost(network: Network) {
                // A switch to another default network arrives as onAvailable for the new one;
                // only losing the network the readings describe means no network.
                if (network != current) return
                val next = manager.activeNetwork?.takeIf { it != network }
                current = next
                emit(read(next, null))
            }
        }
        try {
            manager.registerDefaultNetworkCallback(networkCallback)
            callback = networkCallback
        } catch (_: RuntimeException) {
            // Too many callbacks registered in this process: the first reading stands.
        }
    }

    fun stop() {
        val registered = callback ?: return
        callback = null
        try {
            connectivity?.unregisterNetworkCallback(registered)
        } catch (_: IllegalArgumentException) {
            // Already unregistered.
        }
    }

    private fun read(
        network: Network?,
        given: NetworkCapabilities?,
        givenLink: LinkProperties? = null,
    ): Map<String, Any?> {
        val manager = connectivity ?: return unavailable()
        if (network == null) return unavailable()
        val capabilities = given ?: manager.getNetworkCapabilities(network) ?: return unavailable()
        val kind = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
        val hint = when (kind) {
            "cellular" -> mccMnc()
            else -> linkHintOf(kind, givenLink ?: manager.getLinkProperties(network))
        }
        return buildMap {
            put("available", capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
            put("interface", kind)
            put("metered", !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED))
            if (hint != null) put("fingerprintHint", hint)
        }
    }

    private fun unavailable(): Map<String, Any?> = mapOf("available" to false)

    /** MCC-MNC of the data subscription (`46001`); no permission is needed to read it. */
    private fun mccMnc(): String? {
        val manager = telephony ?: return null
        val subscription = SubscriptionManager.getDefaultDataSubscriptionId()
        val data = if (subscription != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            manager.createForSubscriptionId(subscription)
        } else {
            manager
        }
        val operator = try {
            data.networkOperator
        } catch (_: SecurityException) {
            null
        }
        return operatorHint(operator)
    }

    internal companion object {
        /**
         * MCC-MNC is five or six digits (`46001`); anything else (empty when there is no SIM) is no hint.
         * The same as the native module's `PlatformLifecycle.operatorHint`.
         */
        fun operatorHint(networkOperator: String?): String? =
            networkOperator?.trim()?.takeIf { it.length in 5..6 && it.all(Char::isDigit) }

        /** The hint of a non-cellular link from its default routes and DNS servers ([linkHint]). */
        fun linkHintOf(kind: String, link: LinkProperties?): String? = linkHint(
            kind = kind,
            gateways = link?.routes.orEmpty().filter { it.isDefaultRoute }.mapNotNull { it.gateway },
            dnsServers = link?.dnsServers.orEmpty(),
        )

        /**
         * The identity of a Wi-Fi, Ethernet or other link as 16 hex digits: a SHA-256 over the kind, the
         * default gateways and the DNS servers, each set sorted so their order does not matter. The exact
         * algorithm of the native module's `PlatformLifecycle.linkHint`, so a Flutter app and a native app
         * on the same network report the same hint.
         *
         * Only one address family counts: IPv4 when the link has an IPv4 default gateway, IPv6 otherwise.
         * DHCP hands out the IPv4 gateway and DNS servers together, while IPv6 routes and RDNSS servers
         * often arrive seconds later; mixing the two would report a second, different network a moment
         * after joining. On an IPv6-only link the gateway is usually the router's link-local address,
         * which differs between routers. The device's own addresses and the routed prefixes are left out:
         * they change with DHCP leases and privacy addresses on the same network. Null when the link names
         * neither a gateway nor a DNS server. Only the digest leaves this function, never an address.
         */
        fun linkHint(kind: String, gateways: List<InetAddress>, dnsServers: List<InetAddress>): String? {
            val ipv4 = gateways.any { it is Inet4Address }
            fun hex(addresses: List<InetAddress>): List<String> = addresses
                .filter { (it is Inet4Address) == ipv4 && !it.isAnyLocalAddress && !it.isLoopbackAddress }
                .map { address -> address.address.joinToString("") { "%02x".format(it.toInt() and 0xff) } }
                .distinct()
                .sorted()
            val gatewayPart = hex(gateways)
            val dnsPart = hex(dnsServers)
            if (gatewayPart.isEmpty() && dnsPart.isEmpty()) return null
            val identity = listOf(
                "v1",
                kind,
                "gw=" + gatewayPart.joinToString(","),
                "dns=" + dnsPart.joinToString(","),
            ).joinToString("|")
            val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
            return digest.take(8).joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }
    }
}
