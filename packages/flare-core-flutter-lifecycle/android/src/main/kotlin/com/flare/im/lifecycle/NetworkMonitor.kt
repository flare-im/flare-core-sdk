package com.flare.im.lifecycle

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

/**
 * Follows the default network with `registerDefaultNetworkCallback` and hands every reading to
 * [emit]: `{available, interface, metered, fingerprintHint}`, the current network first.
 *
 * Duplicates are fine: the Dart side reports only changes. Needs `ACCESS_NETWORK_STATE` and
 * nothing else; the fingerprint hint is never an SSID or BSSID.
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
            "wifi", "ethernet" -> gatewayPrefix(givenLink ?: manager.getLinkProperties(network))
            "cellular" -> mccMnc()
            else -> null
        }
        return buildMap {
            put("available", capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
            put("interface", kind)
            put("metered", !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED))
            if (hint != null) put("fingerprintHint", hint)
        }
    }

    private fun unavailable(): Map<String, Any?> = mapOf("available" to false)

    /** MCC-MNC of the data subscription (`460-01`); no permission is needed to read it. */
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
        return formatMccMnc(operator)
    }

    internal companion object {
        /** `46001` → `460-01`; anything that is not 5 or 6 digits → null. */
        fun formatMccMnc(operator: String?): String? {
            val digits = operator?.trim() ?: return null
            if (digits.length !in 5..6 || !digits.all { it in '0'..'9' }) return null
            return "${digits.substring(0, 3)}-${digits.substring(3)}"
        }

        /**
         * The default gateway's IPv4 /24 (`192.168.1`), else a routable IPv6 gateway's /64
         * (`2001:db8:1:2`); link-local IPv6 gateways say nothing about the network and give none.
         */
        fun gatewayPrefix(link: LinkProperties?): String? {
            val gateways = link?.routes
                ?.filter { it.isDefaultRoute && it.hasGateway() }
                ?.mapNotNull { it.gateway }
                ?: return null
            return prefixOf(gateways)
        }

        fun prefixOf(gateways: List<InetAddress>): String? {
            gateways.firstOrNull { it is Inet4Address }?.let { v4 ->
                val bytes = v4.address
                return (0 until 3).joinToString(".") { (bytes[it].toInt() and 0xff).toString() }
            }
            gateways.firstOrNull { it is Inet6Address && !it.isLinkLocalAddress }?.let { v6 ->
                val bytes = v6.address
                return (0 until 4).joinToString(":") { group ->
                    val high = bytes[group * 2].toInt() and 0xff
                    val low = bytes[group * 2 + 1].toInt() and 0xff
                    Integer.toHexString((high shl 8) or low)
                }
            }
            return null
        }
    }
}
