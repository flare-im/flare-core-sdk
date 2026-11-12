import Foundation

/// GENERATED. Do not edit by hand.
/// Plugin listener callbacks.
public protocol PluginEventListener: AnyObject {
    /// A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType.
    func onPluginRealtime(_ event: PluginRealtimeEvent)
    /// The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one.
    func onPluginCatalogChanged(_ event: PluginCatalogChangedEvent)
    /// The engine asks the host to do its part of a plugin host capability (method consent, captureDocument, pickFile, confirmPayment or locateOnce). Show the kit's screen for it and answer with completePluginCapabilityRequest({requestId, result}); the engine waits up to 10 minutes.
    func onPluginCapabilityRequest(_ event: PluginCapabilityRequestEvent)
}

public extension PluginEventListener {
    func onPluginRealtime(_ event: PluginRealtimeEvent) {}
    func onPluginCatalogChanged(_ event: PluginCatalogChangedEvent) {}
    func onPluginCapabilityRequest(_ event: PluginCapabilityRequestEvent) {}
}
