import Foundation

/// GENERATED. Do not edit by hand.
/// Something for an open web bundle page.
public struct PluginBundleEvent: Codable, Sendable {
    /// wire: `sessionId`. The page's session (pluginBundleOpen).
    public let sessionId: String
    /// wire: `envelope`. A bridge event to post to the page as it is: catalog.changed, entity.state, lifecycle.revoked.
    public let envelope: String?
    /// wire: `close`. Close the page: withdrawn, suspended, disabled, replaced, evicted or signedOut.
    public let close: String?

    public init(sessionId: String = "", envelope: String? = nil, close: String? = nil) {
        self.sessionId = sessionId
        self.envelope = envelope
        self.close = close
    }
}
