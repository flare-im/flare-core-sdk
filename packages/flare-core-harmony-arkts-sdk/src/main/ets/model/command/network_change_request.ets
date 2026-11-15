// GENERATED. Do not edit by hand.
import { NetworkInterfaceKind } from '../entity/network_interface_kind';

/** Platform network-change notification. The link supervisor alone decides whether and how to reconnect. */
export interface NetworkChangeRequest {
  /** wire: `available`. Whether a network route is currently available. Omitted means available. */
  available?: boolean;
  /** wire: `interface`. Standardized platform network interface hint. */
  interface?: NetworkInterfaceKind;
  /** wire: `expensive`. Whether the active route is considered expensive by the platform. */
  expensive?: boolean;
  /** wire: `metered`. Whether the active route is metered. */
  metered?: boolean;
  /** wire: `reason`. Optional platform reason string for diagnostics. */
  reason?: string;
  /** wire: `fingerprintHint`. Coarse network identity (native: a 16-hex-digit SHA-256 digest of the interface kind and the default gateway, plus the DNS servers on Android, or the cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID or a raw address. */
  fingerprintHint?: string;
}
