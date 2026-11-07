package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// A prompt really appeared.
public class UpdateMarkPromptedRequest {
    // wire: `build`. Optional. Build the prompt is about; absent when a forced update has no release yet.
    public let build: ?UInt64
    // wire: `form`. sheet, modal or fullscreen.
    public let form: String

    public init(build!: ?UInt64, form!: String) {
        this.build = build
        this.form = form
    }
}
