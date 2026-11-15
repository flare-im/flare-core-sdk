package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Whether the platform presents alerts itself while the app is in the background.
public class SetBackgroundPresenterRequest {
    // wire: `attached`. The platform push module posts local notifications for the engine while the app is in the background.
    public let attached: Bool

    public init(attached!: Bool) {
        this.attached = attached
    }
}
