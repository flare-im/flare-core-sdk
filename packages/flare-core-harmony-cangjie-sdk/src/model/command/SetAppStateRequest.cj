package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Foreground and background notification from the platform lifecycle.
public class SetAppStateRequest {
    // wire: `appState`. Current application state.
    public let appState: AppState

    public init(appState!: AppState) {
        this.appState = appState
    }
}
