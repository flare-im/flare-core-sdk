package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Access directory and current link summary for the diagnostics page.
public class AccessStatus {
    // wire: `loaded`. Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one.
    public let loaded: Bool
    // wire: `serial`. Serial of the loaded access manifest; 0 before loading.
    public let serial: UInt64
    // wire: `source`. Optional. Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source.
    public let source: ?String
    // wire: `stale`. Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes.
    public let stale: Bool
    // wire: `developmentMode`. Endpoints come from development-mode configuration.
    public let developmentMode: Bool
    // wire: `issuedAtMs`. Optional. When the manifest was issued, Unix milliseconds; absent with an empty directory.
    public let issuedAtMs: ?Int64
    // wire: `expiresAtMs`. Optional. When the manifest expires, Unix milliseconds; absent with an empty directory.
    public let expiresAtMs: ?Int64
    // wire: `fetchedAtMs`. Optional. When the manifest reached this device, Unix milliseconds; absent for a seed or development mode.
    public let fetchedAtMs: ?Int64
    // wire: `regionId`. Optional. Home region.
    public let regionId: ?String
    // wire: `cellId`. Optional. Home cell.
    public let cellId: ?String
    // wire: `keystateSerial`. Optional. Serial of the loaded signing key state.
    public let keystateSerial: ?UInt64
    // wire: `accessPointId`. Optional. Access point the IM connection is on.
    public let accessPointId: ?String
    // wire: `protocol`. Optional. Transport of the IM connection: quic or ws.
    public let protocol: ?String
    // wire: `pinned`. Optional. The manual pin, when one is in force.
    public let pinned: ?AccessPin
    // wire: `connectAck`. Optional. CONNECT_ACK diagnostics of the current connection; absent without one.
    public let connectAck: ?AccessConnectAck
    // wire: `refresh`. Optional. Manifest refresh progress; absent in development mode.
    public let refresh: ?AccessRefreshStatus
    // wire: `recovering`. Optional. Present only while every access point has failed and recovery is running.
    public let recovering: ?AccessRecoveringStatus

    public init(loaded!: Bool, serial!: UInt64, source!: ?String, stale!: Bool, developmentMode!: Bool, issuedAtMs!: ?Int64, expiresAtMs!: ?Int64, fetchedAtMs!: ?Int64, regionId!: ?String, cellId!: ?String, keystateSerial!: ?UInt64, accessPointId!: ?String, protocol!: ?String, pinned!: ?AccessPin, connectAck!: ?AccessConnectAck, refresh!: ?AccessRefreshStatus, recovering!: ?AccessRecoveringStatus) {
        this.loaded = loaded
        this.serial = serial
        this.source = source
        this.stale = stale
        this.developmentMode = developmentMode
        this.issuedAtMs = issuedAtMs
        this.expiresAtMs = expiresAtMs
        this.fetchedAtMs = fetchedAtMs
        this.regionId = regionId
        this.cellId = cellId
        this.keystateSerial = keystateSerial
        this.accessPointId = accessPointId
        this.protocol = protocol
        this.pinned = pinned
        this.connectAck = connectAck
        this.refresh = refresh
        this.recovering = recovering
    }
}
