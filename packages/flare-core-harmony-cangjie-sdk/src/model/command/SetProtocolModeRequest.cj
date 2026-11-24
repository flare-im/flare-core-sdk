package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Select the IM connection transport.
public class SetProtocolModeRequest {
    // wire: `mode`. Transport mode: ws, quic, or race.
    public let mode: String

    public init(mode!: String) {
        this.mode = mode
    }
}
