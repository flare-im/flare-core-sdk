// GENERATED. Do not edit by hand.

/// Whether an update reaching a plugin's minimum build is offered to this device.
final class PluginUpgradeStatus {
  /// wire: `available`. A release at or above the floor is offered.
  final bool available;
  /// wire: `build`. That release's build, when available.
  final int? build;

  const PluginUpgradeStatus({
    this.available = false,
    this.build,
  });
}
