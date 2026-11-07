package flare_core_harmony_cangjie_sdk.model.event.access

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One side of an access point switch.
public class AccessEndpoint {
    // wire: `ap`. Access point id.
    public let ap: String
    // wire: `protocol`. Transport: quic or ws.
    public let protocol: String

    public init(ap!: String, protocol!: String) {
        this.ap = ap
        this.protocol = protocol
    }
}
