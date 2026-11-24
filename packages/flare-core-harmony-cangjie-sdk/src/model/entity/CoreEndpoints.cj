package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// CoreEndpoints
public class CoreEndpoints {
    // wire: `baseUrl`. Core API base URL, including any deployment path prefix.
    public let baseUrl: String
    // wire: `mediaBaseUrl`. Optional. Optional media API base. Defaults to the Core API base.
    public let mediaBaseUrl: ?String
    // wire: `quicUrl`. Optional. Optional native QUIC gateway; WebSocket remains available.
    public let quicUrl: ?String
    // wire: `websocketUrl`. Fully qualified WebSocket gateway URL.
    public let websocketUrl: String

    public init(baseUrl!: String, mediaBaseUrl!: ?String, quicUrl!: ?String, websocketUrl!: String) {
        this.baseUrl = baseUrl
        this.mediaBaseUrl = mediaBaseUrl
        this.quicUrl = quicUrl
        this.websocketUrl = websocketUrl
    }
}
