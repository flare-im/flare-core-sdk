// GENERATED. Do not edit by hand.
import '../model/model.dart';

/// Plugin listener callbacks.
abstract class PluginEventListener {
  const PluginEventListener();
  /// A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType.
  void onPluginRealtime(PluginRealtimeEvent event) {}
  /// The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one.
  void onPluginCatalogChanged(PluginCatalogChangedEvent event) {}
  /// The engine asks the host to do its part of a plugin host capability (method consent, captureDocument, pickFile, confirmPayment or locateOnce). Show the kit's screen for it and answer with completePluginCapabilityRequest({requestId, result}); the engine waits up to 10 minutes.
  void onPluginCapabilityRequest(PluginCapabilityRequestEvent event) {}
  /// Something for an open web bundle page: post envelope (a bridge event) to the page as it is; close the page when close is set (withdrawn, suspended, disabled, replaced, evicted or signedOut).
  void onPluginBundleEvent(PluginBundleEvent event) {}
}
