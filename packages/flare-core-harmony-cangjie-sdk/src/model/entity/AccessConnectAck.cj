package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Diagnostics the gateway returned in CONNECT_ACK for the current connection; shown only, nothing acts on them.
public class AccessConnectAck {
    // wire: `gatewayId`. Optional. Gateway instance serving the connection.
    public let gatewayId: ?String
    // wire: `accessPointId`. Optional. Access point the server reports for the connection, when its gateway is configured with one.
    public let accessPointId: ?String
    // wire: `accessSerial`. Optional. Newest access manifest serial the server knows.
    public let accessSerial: ?UInt64
    // wire: `heartbeatIntervalHintSec`. Optional. Gateway heartbeat interval in seconds; the heartbeat itself follows the access policy.
    public let heartbeatIntervalHintSec: ?UInt32
    // wire: `accessPointMismatch`. The server reports a different access point than the client chose; logged and counted, the connection stays up.
    public let accessPointMismatch: Bool

    public init(gatewayId!: ?String, accessPointId!: ?String, accessSerial!: ?UInt64, heartbeatIntervalHintSec!: ?UInt32, accessPointMismatch!: Bool) {
        this.gatewayId = gatewayId
        this.accessPointId = accessPointId
        this.accessSerial = accessSerial
        this.heartbeatIntervalHintSec = heartbeatIntervalHintSec
        this.accessPointMismatch = accessPointMismatch
    }
}
