package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Reads the update state.
public class UpdateGetStateRequest {
    // wire: `foreground`. Optional. The app just returned to the foreground: count that first.
    public let foreground: ?Bool

    public init(foreground!: ?Bool) {
        this.foreground = foreground
    }
}
