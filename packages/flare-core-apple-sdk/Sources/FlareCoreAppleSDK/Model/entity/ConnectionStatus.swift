import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of connection://status and the value of connection.getStatus. Every field is present (null without a value): hosts replace their copy whole on every event and hand it to the Kit ConnectionNotice unchanged.
public struct ConnectionStatus: Codable, Sendable {
    /// wire: `phase`. Where the link supervisor is.
    public let phase: ConnectionPhase
    /// wire: `quality`. Line quality; set only while online.
    public let quality: ConnectionQuality?
    /// wire: `accessPointId`. Current (or connecting) access point.
    public let accessPointId: String?
    /// wire: `cellId`. Cell of the current access point.
    public let cellId: String?
    /// wire: `regionId`. Region of the current access point.
    public let regionId: String?
    /// wire: `protocol`. Transport of the current connection: quic or ws.
    public let `protocol`: String?
    /// wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample).
    public let rttMs: UInt32?
    /// wire: `attempt`. Which round of the current recovery this is; zero once online.
    public let attempt: UInt32
    /// wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay).
    public let nextRetryAt: Int64?
    /// wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: failure, drain, failback, manual or manifest.
    public let reason: String?
    /// wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase.
    public let developmentMode: Bool

    public init(phase: ConnectionPhase, quality: ConnectionQuality? = nil, accessPointId: String? = nil, cellId: String? = nil, regionId: String? = nil, `protocol`: String? = nil, rttMs: UInt32? = nil, attempt: UInt32 = 0, nextRetryAt: Int64? = nil, reason: String? = nil, developmentMode: Bool = false) {
        self.phase = phase
        self.quality = quality
        self.accessPointId = accessPointId
        self.cellId = cellId
        self.regionId = regionId
        self.`protocol` = `protocol`
        self.rttMs = rttMs
        self.attempt = attempt
        self.nextRetryAt = nextRetryAt
        self.reason = reason
        self.developmentMode = developmentMode
    }
}
