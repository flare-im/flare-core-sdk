import Foundation

/// GENERATED. Do not edit by hand.
/// One access point of the home cell with its health on the current network.
public struct AccessPointInfo: Codable, Sendable {
    /// wire: `accessPointId`. Access point id.
    public let accessPointId: String
    /// wire: `regionId`. Region the access point is in.
    public let regionId: String
    /// wire: `host`. Host name shown on the diagnostics page.
    public let host: String
    /// wire: `status`. Manifest status: active, draining, disabled or unknown.
    public let status: String
    /// wire: `rttMs`. Smoothed round trip on the current network, when measured.
    public let rttMs: Double?
    /// wire: `breaker`. Circuit breaker state: closed, open or halfOpen.
    public let breaker: String
    /// wire: `protocolWinner`. Protocol that last won the race on this network: quic or ws.
    public let protocolWinner: String?
    /// wire: `pinned`. Whether this access point is manually pinned.
    public let pinned: Bool
    /// wire: `current`. Whether the IM connection is on this access point.
    public let current: Bool

    public init(accessPointId: String = "", regionId: String = "", host: String = "", status: String = "", rttMs: Double? = nil, breaker: String = "", protocolWinner: String? = nil, pinned: Bool = false, current: Bool = false) {
        self.accessPointId = accessPointId
        self.regionId = regionId
        self.host = host
        self.status = status
        self.rttMs = rttMs
        self.breaker = breaker
        self.protocolWinner = protocolWinner
        self.pinned = pinned
        self.current = current
    }
}
