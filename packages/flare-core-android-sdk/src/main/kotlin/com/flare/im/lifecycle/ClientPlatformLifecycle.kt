package com.flare.im.lifecycle

import android.content.Context
import com.flare.im.api.connection.ConnectionApi
import com.flare.im.api.lifecycle.LifecycleApi
import com.flare.im.model.command.NetworkChangeRequest
import com.flare.im.model.command.SetAppStateRequest
import com.flare.im.model.entity.AppState
import com.flare.im.model.entity.NetworkInterfaceKind

/** Builds the platform lifecycle a client installs after `init`. */
fun interface PlatformLifecycleFactory {
    fun create(connection: ConnectionApi, lifecycle: LifecycleApi): PlatformLifecycle
}

/**
 * The platform lifecycle of a core client: network changes go to `connection.notifyNetworkChange`,
 * foreground and background to `lifecycle.setAppState`.
 */
fun PlatformLifecycle.Companion.forClient(
    connection: ConnectionApi,
    lifecycle: LifecycleApi,
    network: PlatformNetworkSource,
    appState: PlatformAppStateSource,
    onError: (Throwable) -> Unit = {},
): PlatformLifecycle = PlatformLifecycle(
    notifyNetworkChange = { state, reason ->
        connection.notifyNetworkChange(
            NetworkChangeRequest(
                available = state.available,
                `interface` = state.interfaceKind?.let { kind ->
                    when (kind) {
                        PlatformNetworkInterface.UNKNOWN -> NetworkInterfaceKind.UNKNOWN
                        PlatformNetworkInterface.WIFI -> NetworkInterfaceKind.WIFI
                        PlatformNetworkInterface.CELLULAR -> NetworkInterfaceKind.CELLULAR
                        PlatformNetworkInterface.ETHERNET -> NetworkInterfaceKind.ETHERNET
                        PlatformNetworkInterface.OTHER -> NetworkInterfaceKind.OTHER
                    }
                },
                expensive = state.expensive,
                metered = state.metered,
                reason = reason,
                fingerprintHint = state.fingerprintHint,
            ),
        )
    },
    setAppState = { state ->
        lifecycle.setAppState(
            SetAppStateRequest(
                when (state) {
                    PlatformAppState.FOREGROUND -> AppState.FOREGROUND
                    PlatformAppState.BACKGROUND -> AppState.BACKGROUND
                },
            ),
        )
    },
    network = network,
    appState = appState,
    onError = onError,
)

/** The running app's default network and process lifecycle, reported to a core client. */
fun PlatformLifecycle.Companion.system(context: Context): PlatformLifecycleFactory {
    val app = context.applicationContext ?: context
    return PlatformLifecycleFactory { connection, lifecycle ->
        PlatformLifecycle.forClient(connection, lifecycle, ConnectivityNetworkSource(app), ProcessAppStateSource())
    }
}
