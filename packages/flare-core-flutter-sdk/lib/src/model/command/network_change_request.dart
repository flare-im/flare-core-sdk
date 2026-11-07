// GENERATED. Do not edit by hand.
import '../entity/network_interface_kind.dart';

/// Platform network-change notification. The link supervisor alone decides whether and how to reconnect.
final class NetworkChangeRequest {
  /// wire: `available`. Whether a network route is currently available. Omitted means available.
  final bool? available;
  /// wire: `interface`. Standardized platform network interface hint.
  final NetworkInterfaceKind? interface;
  /// wire: `expensive`. Whether the active route is considered expensive by the platform.
  final bool? expensive;
  /// wire: `metered`. Whether the active route is metered.
  final bool? metered;
  /// wire: `reason`. Optional platform reason string for diagnostics.
  final String? reason;
  /// wire: `fingerprintHint`. Coarse network identity (native: Wi-Fi gateway prefix or cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID.
  final String? fingerprintHint;

  const NetworkChangeRequest({
    this.available,
    this.interface,
    this.expensive,
    this.metered,
    this.reason,
    this.fingerprintHint,
  });
}
