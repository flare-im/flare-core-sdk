import Foundation

/// GENERATED. Do not edit by hand.
/// Foreground and background notification from the platform lifecycle.
public struct SetAppStateRequest: Codable, Sendable {
    /// wire: `appState`. Current application state.
    public let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }
}
