import Foundation

/// GENERATED. Do not edit by hand.
/// Access directory and current link summary for the diagnostics page.
public struct AccessStatus: Codable, Sendable {
    /// wire: `loaded`. Whether the directory holds a usable manifest. False means there is no access point to connect to until bootstrap or a recovery link brings one.
    public let loaded: Bool
    /// wire: `serial`. Serial of the loaded access manifest; 0 before loading.
    public let serial: UInt64
    /// wire: `source`. Where the manifest came from: seed, https:<mirror base>, wellKnown:<apId>, recovery, development, or none when the directory is empty. A restart keeps the original source.
    public let source: String?
    /// wire: `stale`. Whether the manifest is past expiresAtMs: it still connects, and refresh retries every 10 minutes.
    public let stale: Bool
    /// wire: `developmentMode`. Endpoints come from development-mode configuration.
    public let developmentMode: Bool
    /// wire: `issuedAtMs`. When the manifest was issued, Unix milliseconds; absent with an empty directory.
    public let issuedAtMs: Int64?
    /// wire: `expiresAtMs`. When the manifest expires, Unix milliseconds; absent with an empty directory.
    public let expiresAtMs: Int64?
    /// wire: `fetchedAtMs`. When the manifest reached this device, Unix milliseconds; absent for a seed or development mode.
    public let fetchedAtMs: Int64?
    /// wire: `regionId`. Home region.
    public let regionId: String?
    /// wire: `cellId`. Home cell.
    public let cellId: String?
    /// wire: `keystateSerial`. Serial of the loaded signing key state.
    public let keystateSerial: UInt64?
    /// wire: `accessPointId`. Access point the IM connection is on.
    public let accessPointId: String?
    /// wire: `protocol`. Transport of the IM connection: quic or ws.
    public let `protocol`: String?
    /// wire: `pinned`. The manual pin, when one is in force.
    public let pinned: AccessPin?
    /// wire: `connectAck`. CONNECT_ACK diagnostics of the current connection; absent without one.
    public let connectAck: AccessConnectAck?
    /// wire: `refresh`. Manifest refresh progress; absent in development mode.
    public let refresh: AccessRefreshStatus?
    /// wire: `recovering`. Present only while every access point has failed and recovery is running.
    public let recovering: AccessRecoveringStatus?

    public init(loaded: Bool = false, serial: UInt64 = 0, source: String? = nil, stale: Bool = false, developmentMode: Bool = false, issuedAtMs: Int64? = nil, expiresAtMs: Int64? = nil, fetchedAtMs: Int64? = nil, regionId: String? = nil, cellId: String? = nil, keystateSerial: UInt64? = nil, accessPointId: String? = nil, `protocol`: String? = nil, pinned: AccessPin? = nil, connectAck: AccessConnectAck? = nil, refresh: AccessRefreshStatus? = nil, recovering: AccessRecoveringStatus? = nil) {
        self.loaded = loaded
        self.serial = serial
        self.source = source
        self.stale = stale
        self.developmentMode = developmentMode
        self.issuedAtMs = issuedAtMs
        self.expiresAtMs = expiresAtMs
        self.fetchedAtMs = fetchedAtMs
        self.regionId = regionId
        self.cellId = cellId
        self.keystateSerial = keystateSerial
        self.accessPointId = accessPointId
        self.`protocol` = `protocol`
        self.pinned = pinned
        self.connectAck = connectAck
        self.refresh = refresh
        self.recovering = recovering
    }
}
