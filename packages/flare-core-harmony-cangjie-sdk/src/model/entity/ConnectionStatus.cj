package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of connection://status and the value of connection.getStatus. Every field is present (null without a value): hosts replace their copy whole on every event and hand it to the Kit ConnectionNotice unchanged.
public class ConnectionStatus {
    // wire: `phase`. Where the link supervisor is.
    public let phase: ConnectionPhase
    // wire: `quality`. Optional. Line quality; set only while online.
    public let quality: ?ConnectionQuality
    // wire: `accessPointId`. Optional. Current (or connecting) access point.
    public let accessPointId: ?String
    // wire: `cellId`. Optional. Cell of the current access point.
    public let cellId: ?String
    // wire: `regionId`. Optional. Region of the current access point.
    public let regionId: ?String
    // wire: `protocol`. Optional. Transport of the current connection: quic or ws.
    public let protocol: ?String
    // wire: `rttMs`. Optional. Latest heartbeat round trip (the handshake time before the first sample).
    public let rttMs: ?UInt32
    // wire: `attempt`. Which round of the current recovery this is; zero once online.
    public let attempt: UInt32
    // wire: `nextRetryAt`. Optional. When the next round starts: Unix milliseconds on the device clock (not the server clock, not a delay).
    public let nextRetryAt: ?Int64
    // wire: `reason`. Optional. actionRequired: kicked, expired, upgradeRequired or tenantUnavailable. switching: failure, drain, failback, manual or manifest.
    public let reason: ?String
    // wire: `developmentMode`. Endpoints come from development-mode configuration: the Kit shows its development badge in every phase.
    public let developmentMode: Bool

    public init(phase!: ConnectionPhase, quality!: ?ConnectionQuality, accessPointId!: ?String, cellId!: ?String, regionId!: ?String, protocol!: ?String, rttMs!: ?UInt32, attempt!: UInt32, nextRetryAt!: ?Int64, reason!: ?String, developmentMode!: Bool) {
        this.phase = phase
        this.quality = quality
        this.accessPointId = accessPointId
        this.cellId = cellId
        this.regionId = regionId
        this.protocol = protocol
        this.rttMs = rttMs
        this.attempt = attempt
        this.nextRetryAt = nextRetryAt
        this.reason = reason
        this.developmentMode = developmentMode
    }
}
