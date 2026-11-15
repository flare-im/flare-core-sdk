package com.flare.im.lifecycle

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.net.Inet4Address
import java.net.InetAddress
import java.security.MessageDigest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch

/** Whether the app is in the foreground or the background. */
enum class PlatformAppState(val wireValue: String) {
    FOREGROUND("foreground"),
    BACKGROUND("background"),
}

/** The kind of the active network interface; [wireValue] is the SDK wire value. */
enum class PlatformNetworkInterface(val wireValue: String) {
    UNKNOWN("unknown"),
    WIFI("wifi"),
    CELLULAR("cellular"),
    ETHERNET("ethernet"),
    OTHER("other"),
}

/** The network as the platform sees it. */
data class PlatformNetworkState(
    val available: Boolean,
    val interfaceKind: PlatformNetworkInterface? = null,
    val expensive: Boolean? = null,
    val metered: Boolean? = null,
    /**
     * Coarse network identity, hashed locally into the network fingerprint. Wi-Fi, Ethernet and other
     * links: a digest of the kind with the link's default gateways and DNS servers
     * ([PlatformLifecycle.linkHint]), which tells two networks apart without location permission and
     * carries no address. Cellular: the operator's MCC-MNC. Never an SSID, never a raw address.
     */
    val fingerprintHint: String? = null,
)

/** Where network changes come from: [start] delivers the current state first, then every change. */
interface PlatformNetworkSource {
    fun start(onChange: (PlatformNetworkState) -> Unit)
    fun stop()
}

/** Where foreground and background come from: [start] delivers the current state first. */
interface PlatformAppStateSource {
    fun start(onChange: (PlatformAppState) -> Unit)
    fun stop()
}

/**
 * Reports the platform's network and foreground state to an SDK.
 *
 * It references no SDK: the two report functions are injected, so it is reusable as is. The core
 * client wires them to `connection.notifyNetworkChange` and `lifecycle.setAppState`
 * ([PlatformLifecycle.Companion.forClient]), installs it when `init` succeeds (unless the init
 * request carries `installPlatformLifecycle = false`) and removes it on `uninit`, `dispose` and
 * `hardReset`. The default network comes from `ConnectivityManager.registerDefaultNetworkCallback`,
 * foreground and background from `ProcessLifecycleOwner`. The current state is reported once on
 * install, repeats are dropped, and reports are delivered in order. What to do with them is the
 * SDK's decision; apps add no wiring of their own. Needs only `ACCESS_NETWORK_STATE`.
 */
class PlatformLifecycle(
    /** Reports a network change; the reason is `initial` for the first report, then `network_change`. */
    private val notifyNetworkChange: suspend (state: PlatformNetworkState, reason: String) -> Unit,
    /** Reports the app moving to the foreground or the background. */
    private val setAppState: suspend (state: PlatformAppState) -> Unit,
    private val network: PlatformNetworkSource,
    private val appState: PlatformAppStateSource,
    /** Called when a report fails; reports are best effort. */
    private val onError: (Throwable) -> Unit = {},
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
) {
    private sealed interface Signal {
        data class Network(val state: PlatformNetworkState) : Signal
        data class App(val state: PlatformAppState) : Signal
    }

    private val lock = Any()
    private val signals = Channel<Signal>(Channel.UNLIMITED)
    private var worker: Job? = null
    private var installed = false
    private var disposed = false

    /** Starts listening and reports the current state. Calling it again does nothing. */
    fun install(): PlatformLifecycle {
        synchronized(lock) {
            if (installed || disposed) return this
            installed = true
            worker = scope.launch { report() }
        }
        network.start { signals.trySend(Signal.Network(it)) }
        appState.start { signals.trySend(Signal.App(it)) }
        return this
    }

    /** Stops listening; later changes are not reported. */
    fun dispose() {
        val job = synchronized(lock) {
            if (disposed) return
            disposed = true
            if (!installed) return
            worker
        }
        network.stop()
        appState.stop()
        signals.close()
        job?.cancel()
    }

    private suspend fun report() {
        var lastNetwork: PlatformNetworkState? = null
        var lastAppState: PlatformAppState? = null
        for (signal in signals) {
            when (signal) {
                is Signal.Network -> {
                    if (signal.state == lastNetwork) continue
                    val reason = if (lastNetwork == null) "initial" else "network_change"
                    lastNetwork = signal.state
                    deliver { notifyNetworkChange(signal.state, reason) }
                }
                is Signal.App -> {
                    if (signal.state == lastAppState) continue
                    lastAppState = signal.state
                    deliver { setAppState(signal.state) }
                }
            }
        }
    }

    private suspend fun deliver(report: suspend () -> Unit) {
        try {
            report()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Throwable) {
            onError(error)
        }
    }

    companion object {
        /**
         * The identity of a Wi-Fi, Ethernet or other link as 16 hex digits: a SHA-256 over the kind, the
         * default gateways and the DNS servers, each set sorted so their order does not matter.
         *
         * Only one address family counts: IPv4 when the link has an IPv4 default gateway, IPv6 otherwise.
         * DHCP hands out the IPv4 gateway and DNS servers together, while IPv6 routes and RDNSS servers
         * often arrive seconds later; mixing the two would report a second, different network a moment
         * after joining. On an IPv6-only link the gateway is usually the router's link-local address,
         * which differs between routers. The device's own addresses and the routed prefixes are left out:
         * they change with DHCP leases and privacy addresses on the same network. Null when the link names
         * neither a gateway nor a DNS server. Only the digest leaves this function, never an address.
         */
        internal fun linkHint(
            kind: PlatformNetworkInterface,
            gateways: List<InetAddress>,
            dnsServers: List<InetAddress>,
        ): String? {
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
                kind.wireValue,
                "gw=" + gatewayPart.joinToString(","),
                "dns=" + dnsPart.joinToString(","),
            ).joinToString("|")
            val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
            return digest.take(8).joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }

        /** MCC-MNC is five or six digits; anything else (empty when there is no SIM) is no hint. */
        internal fun operatorHint(networkOperator: String?): String? =
            networkOperator?.trim()?.takeIf { it.length in 5..6 && it.all(Char::isDigit) }
    }
}

/**
 * The default network from `ConnectivityManager`. Needs `ACCESS_NETWORK_STATE` only (no location
 * permission): the Wi-Fi and Ethernet hint is a digest of the link's default gateways and DNS servers
 * ([PlatformLifecycle.linkHint]), the cellular hint the operator's MCC-MNC.
 */
class ConnectivityNetworkSource(context: Context) : PlatformNetworkSource {
    private val context = context.applicationContext ?: context
    private val manager = this.context.getSystemService(ConnectivityManager::class.java)
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun start(onChange: (PlatformNetworkState) -> Unit) {
        val manager = manager ?: return
        stop()
        // The current network first; with no network there is no callback to say so.
        onChange(current(manager))
        val callback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            DefaultNetworkCallback(onChange)
        } else {
            // API 23 has no default-network callback: re-read the active network on every change.
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = onChange(current(manager))
                override fun onLost(network: Network) = onChange(current(manager))
                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
                    onChange(current(manager))
                override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) =
                    onChange(current(manager))
            }
        }
        this.callback = callback
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.registerDefaultNetworkCallback(callback)
            } else {
                manager.registerNetworkCallback(
                    NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(),
                    callback,
                )
            }
        }.onFailure { this.callback = null }
    }

    override fun stop() {
        val callback = callback ?: return
        this.callback = null
        runCatching { manager?.unregisterNetworkCallback(callback) }
    }

    private fun current(manager: ConnectivityManager): PlatformNetworkState {
        val network = manager.activeNetwork ?: return PlatformNetworkState(available = false)
        return state(manager.getNetworkCapabilities(network), manager.getLinkProperties(network))
    }

    private fun state(capabilities: NetworkCapabilities?, properties: LinkProperties?): PlatformNetworkState {
        if (capabilities == null || !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            return PlatformNetworkState(available = false)
        }
        val kind = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> PlatformNetworkInterface.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> PlatformNetworkInterface.CELLULAR
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> PlatformNetworkInterface.ETHERNET
            else -> PlatformNetworkInterface.OTHER
        }
        val hint = when (kind) {
            PlatformNetworkInterface.CELLULAR -> PlatformLifecycle.operatorHint(networkOperator())
            else -> PlatformLifecycle.linkHint(
                kind = kind,
                gateways = properties?.routes.orEmpty().filter { it.isDefaultRoute }.mapNotNull { it.gateway },
                dnsServers = properties?.dnsServers.orEmpty(),
            )
        }
        return PlatformNetworkState(
            available = true,
            interfaceKind = kind,
            metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
            fingerprintHint = hint,
        )
    }

    private fun networkOperator(): String? = runCatching {
        context.getSystemService(TelephonyManager::class.java)?.networkOperator
    }.getOrNull()

    /**
     * Tracks the default network from the callback's own arguments, which are current. A new
     * default network is reported once both its capabilities and its link are known, so no
     * half-known state (Wi-Fi without its gateway) reaches the fingerprint.
     */
    private inner class DefaultNetworkCallback(
        private val onChange: (PlatformNetworkState) -> Unit,
    ) : ConnectivityManager.NetworkCallback() {
        private var network: Network? = null
        private var capabilities: NetworkCapabilities? = null
        private var properties: LinkProperties? = null

        override fun onAvailable(network: Network) {
            track(network)
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            track(network)
            this.capabilities = capabilities
            report()
        }

        override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) {
            track(network)
            this.properties = properties
            report()
        }

        override fun onLost(network: Network) {
            if (network != this.network) return
            this.network = null
            capabilities = null
            properties = null
            onChange(PlatformNetworkState(available = false))
        }

        private fun track(network: Network) {
            if (network == this.network) return
            this.network = network
            capabilities = null
            properties = null
        }

        private fun report() {
            val capabilities = capabilities ?: return
            val properties = properties ?: return
            onChange(state(capabilities, properties))
        }
    }
}

/** Foreground and background from `ProcessLifecycleOwner` (started = foreground). */
class ProcessAppStateSource : PlatformAppStateSource {
    private val main = Handler(Looper.getMainLooper())
    private var observer: DefaultLifecycleObserver? = null

    override fun start(onChange: (PlatformAppState) -> Unit) {
        val observer = object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = onChange(PlatformAppState.FOREGROUND)
            override fun onStop(owner: LifecycleOwner) = onChange(PlatformAppState.BACKGROUND)
        }
        main.post {
            this.observer?.let { ProcessLifecycleOwner.get().lifecycle.removeObserver(it) }
            this.observer = observer
            val lifecycle = ProcessLifecycleOwner.get().lifecycle
            onChange(
                if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) PlatformAppState.FOREGROUND else PlatformAppState.BACKGROUND,
            )
            lifecycle.addObserver(observer)
        }
    }

    override fun stop() {
        main.post {
            observer?.let { ProcessLifecycleOwner.get().lifecycle.removeObserver(it) }
            observer = null
        }
    }
}
