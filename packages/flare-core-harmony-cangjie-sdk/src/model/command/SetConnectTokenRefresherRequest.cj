package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Installs or removes the host's connect token refresher at the native boundary. Platform packages build it from their one host function; hosts do not send it themselves.
public class SetConnectTokenRefresherRequest {
    // wire: `enabled`. Whether a refresher is installed.
    public let enabled: Bool

    public init(enabled!: Bool) {
        this.enabled = enabled
    }
}
