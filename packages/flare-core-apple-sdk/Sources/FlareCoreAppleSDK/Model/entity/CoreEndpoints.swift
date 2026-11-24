import Foundation

/// GENERATED. Do not edit by hand.
/// CoreEndpoints
public struct CoreEndpoints: Codable, Sendable {
    /// wire: `baseUrl`. Core API base URL, including any deployment path prefix.
    public let baseUrl: String
    /// wire: `mediaBaseUrl`. Optional media API base. Defaults to the Core API base.
    public let mediaBaseUrl: String?
    /// wire: `quicUrl`. Optional native QUIC gateway; WebSocket remains available.
    public let quicUrl: String?
    /// wire: `websocketUrl`. Fully qualified WebSocket gateway URL.
    public let websocketUrl: String

    public init(baseUrl: String = "", mediaBaseUrl: String? = nil, quicUrl: String? = nil, websocketUrl: String = "") {
        self.baseUrl = baseUrl
        self.mediaBaseUrl = mediaBaseUrl
        self.quicUrl = quicUrl
        self.websocketUrl = websocketUrl
    }
}
