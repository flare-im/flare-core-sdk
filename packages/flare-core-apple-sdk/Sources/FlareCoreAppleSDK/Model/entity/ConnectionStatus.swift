import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of connection://status and the value of connection.getStatus. Hosts replace their copy whole on every event. endpointRevision is present for host-selected endpoints.
public struct ConnectionStatus: Codable, Sendable {
    /// wire: `phase`. Where the link supervisor is.
    public let phase: ConnectionPhase
    /// wire: `quality`. Line quality; set only while online.
    public let quality: ConnectionQuality?
    /// wire: `protocol`. Transport of the current connection: quic or ws.
    public let `protocol`: String?
    /// wire: `endpointRevision`. Generation of the accepted host-selected address group.
    public let endpointRevision: UInt32?
    /// wire: `rttMs`. Latest heartbeat round trip (the handshake time before the first sample).
    public let rttMs: UInt32?
    /// wire: `attempt`. Which round of the current recovery this is; zero once online.
    public let attempt: UInt32
    /// wire: `nextRetryAt`. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay).
    public let nextRetryAt: Int64?
    /// wire: `reason`. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: drain or manual. Transport failure: transportUnavailable.
    public let reason: String?
    /// wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase.
    public let developmentMode: Bool

    public init(phase: ConnectionPhase, quality: ConnectionQuality? = nil, `protocol`: String? = nil, endpointRevision: UInt32? = nil, rttMs: UInt32? = nil, attempt: UInt32 = 0, nextRetryAt: Int64? = nil, reason: String? = nil, developmentMode: Bool = false) {
        self.phase = phase
        self.quality = quality
        self.`protocol` = `protocol`
        self.endpointRevision = endpointRevision
        self.rttMs = rttMs
        self.attempt = attempt
        self.nextRetryAt = nextRetryAt
        self.reason = reason
        self.developmentMode = developmentMode
    }
}
