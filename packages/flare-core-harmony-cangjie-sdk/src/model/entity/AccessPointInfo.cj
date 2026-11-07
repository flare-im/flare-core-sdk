package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One access point of the home cell with its health on the current network.
public class AccessPointInfo {
    // wire: `accessPointId`. Access point id.
    public let accessPointId: String
    // wire: `regionId`. Region the access point is in.
    public let regionId: String
    // wire: `host`. Host name shown on the diagnostics page.
    public let host: String
    // wire: `status`. Manifest status: active, draining, disabled or unknown.
    public let status: String
    // wire: `rttMs`. Optional. Smoothed round trip on the current network, when measured.
    public let rttMs: ?Float64
    // wire: `breaker`. Circuit breaker state: closed, open or halfOpen.
    public let breaker: String
    // wire: `protocolWinner`. Optional. Protocol that last won the race on this network: quic or ws.
    public let protocolWinner: ?String
    // wire: `pinned`. Whether this access point is manually pinned.
    public let pinned: Bool
    // wire: `current`. Whether the IM connection is on this access point.
    public let current: Bool

    public init(accessPointId!: String, regionId!: String, host!: String, status!: String, rttMs!: ?Float64, breaker!: String, protocolWinner!: ?String, pinned!: Bool, current!: Bool) {
        this.accessPointId = accessPointId
        this.regionId = regionId
        this.host = host
        this.status = status
        this.rttMs = rttMs
        this.breaker = breaker
        this.protocolWinner = protocolWinner
        this.pinned = pinned
        this.current = current
    }
}
