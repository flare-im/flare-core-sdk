package com.flare.im.model.command

import com.flare.im.model.entity.NetworkInterfaceKind

/** GENERATED. Do not edit by hand. */
/** Platform network-change notification. The link supervisor alone decides whether and how to reconnect. */
data class NetworkChangeRequest(
    /** wire: `available`. Whether a network route is currently available. Omitted means available. */
    val available: Boolean? = null,
    /** wire: `interface`. Standardized platform network interface hint. */
    val `interface`: NetworkInterfaceKind? = null,
    /** wire: `expensive`. Whether the active route is considered expensive by the platform. */
    val expensive: Boolean? = null,
    /** wire: `metered`. Whether the active route is metered. */
    val metered: Boolean? = null,
    /** wire: `reason`. Optional platform reason string for diagnostics. */
    val reason: String? = null,
    /** wire: `fingerprintHint`. Coarse network identity (native: a 16-hex-digit SHA-256 digest of the interface kind and the default gateway, plus the DNS servers on Android, or the cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID or a raw address. */
    val fingerprintHint: String? = null,
)
