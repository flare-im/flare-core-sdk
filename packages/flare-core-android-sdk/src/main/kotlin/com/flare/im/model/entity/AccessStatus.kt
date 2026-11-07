package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Access directory and current link summary for the diagnostics page. */
data class AccessStatus(
    /** wire: `loaded`. Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one. */
    val loaded: Boolean = false,
    /** wire: `serial`. Serial of the loaded access manifest; 0 before loading. */
    val serial: Long = 0L,
    /** wire: `source`. Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source. */
    val source: String? = null,
    /** wire: `stale`. Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes. */
    val stale: Boolean = false,
    /** wire: `developmentMode`. Endpoints come from development-mode configuration. */
    val developmentMode: Boolean = false,
    /** wire: `issuedAtMs`. When the manifest was issued, Unix milliseconds; absent with an empty directory. */
    val issuedAtMs: Long? = null,
    /** wire: `expiresAtMs`. When the manifest expires, Unix milliseconds; absent with an empty directory. */
    val expiresAtMs: Long? = null,
    /** wire: `fetchedAtMs`. When the manifest reached this device, Unix milliseconds; absent for a seed or development mode. */
    val fetchedAtMs: Long? = null,
    /** wire: `regionId`. Home region. */
    val regionId: String? = null,
    /** wire: `cellId`. Home cell. */
    val cellId: String? = null,
    /** wire: `keystateSerial`. Serial of the loaded signing key state. */
    val keystateSerial: Long? = null,
    /** wire: `accessPointId`. Access point the IM connection is on. */
    val accessPointId: String? = null,
    /** wire: `protocol`. Transport of the IM connection: quic or ws. */
    val protocol: String? = null,
    /** wire: `pinned`. The manual pin, when one is in force. */
    val pinned: AccessPin? = null,
    /** wire: `connectAck`. CONNECT_ACK diagnostics of the current connection; absent without one. */
    val connectAck: AccessConnectAck? = null,
    /** wire: `refresh`. Manifest refresh progress; absent in development mode. */
    val refresh: AccessRefreshStatus? = null,
    /** wire: `recovering`. Present only while every access point has failed and recovery is running. */
    val recovering: AccessRecoveringStatus? = null,
)
