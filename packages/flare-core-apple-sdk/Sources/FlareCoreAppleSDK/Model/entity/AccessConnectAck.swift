import Foundation

/// GENERATED. Do not edit by hand.
/// Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them.
public struct AccessConnectAck: Codable, Sendable {
    /// wire: `gatewayId`. Gateway instance serving the connection.
    public let gatewayId: String?
    /// wire: `accessPointId`. Access point the server reports for the connection, when its gateway is configured with one.
    public let accessPointId: String?
    /// wire: `accessSerial`. Newest access manifest serial the server knows.
    public let accessSerial: UInt64?
    /// wire: `heartbeatIntervalHintSec`. Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy.
    public let heartbeatIntervalHintSec: UInt32?
    /// wire: `accessPointMismatch`. The server reports a different access point than the client chose; logged and counted, the connection stays up.
    public let accessPointMismatch: Bool

    public init(gatewayId: String? = nil, accessPointId: String? = nil, accessSerial: UInt64? = nil, heartbeatIntervalHintSec: UInt32? = nil, accessPointMismatch: Bool = false) {
        self.gatewayId = gatewayId
        self.accessPointId = accessPointId
        self.accessSerial = accessSerial
        self.heartbeatIntervalHintSec = heartbeatIntervalHintSec
        self.accessPointMismatch = accessPointMismatch
    }
}
