package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of connection://status and the value of connection.getStatus. Hosts replace their copy whole on every event. endpointRevision is present for host-selected endpoints.
public class ConnectionStatus {
    // wire: `phase`. Where the link supervisor is.
    public let phase: ConnectionPhase
    // wire: `quality`. Optional. Line quality; set only while online.
    public let quality: ?ConnectionQuality
    // wire: `protocol`. Optional. Transport of the current connection: quic or ws.
    public let protocol: ?String
    // wire: `endpointRevision`. Optional. Generation of the accepted host-selected address group.
    public let endpointRevision: ?UInt32
    // wire: `rttMs`. Optional. Latest heartbeat round trip (the handshake time before the first sample).
    public let rttMs: ?UInt32
    // wire: `attempt`. Which round of the current recovery this is; zero once online.
    public let attempt: UInt32
    // wire: `nextRetryAt`. Optional. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay).
    public let nextRetryAt: ?Int64
    // wire: `reason`. Optional. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: drain or manual. Transport failure: transportUnavailable.
    public let reason: ?String
    // wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase.
    public let developmentMode: Bool

    public init(phase!: ConnectionPhase, quality!: ?ConnectionQuality, protocol!: ?String, endpointRevision!: ?UInt32, rttMs!: ?UInt32, attempt!: UInt32, nextRetryAt!: ?Int64, reason!: ?String, developmentMode!: Bool) {
        this.phase = phase
        this.quality = quality
        this.protocol = protocol
        this.endpointRevision = endpointRevision
        this.rttMs = rttMs
        this.attempt = attempt
        this.nextRetryAt = nextRetryAt
        this.reason = reason
        this.developmentMode = developmentMode
    }
}
