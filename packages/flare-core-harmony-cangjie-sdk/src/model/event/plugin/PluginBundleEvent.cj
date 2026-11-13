package flare_core_harmony_cangjie_sdk.model.event.plugin

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Something for an open web bundle page.
public class PluginBundleEvent {
    // wire: `sessionId`. The page's session (pluginBundleOpen).
    public let sessionId: String
    // wire: `envelope`. Optional. A bridge event to post to the page as it is: catalog.changed, entity.state, lifecycle.revoked.
    public let envelope: ?String
    // wire: `close`. Optional. Close the page: withdrawn, suspended, disabled, replaced, evicted or signedOut.
    public let close: ?String

    public init(sessionId!: String, envelope!: ?String, close!: ?String) {
        this.sessionId = sessionId
        this.envelope = envelope
        this.close = close
    }
}
