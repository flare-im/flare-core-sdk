import Foundation

/// GENERATED. Do not edit by hand.
/// Platform network-change notification. The link supervisor alone decides whether and how to reconnect.
public struct NetworkChangeRequest: Codable, Sendable {
    /// wire: `available`. Whether a network route is currently available. Omitted means available.
    public let available: Bool?
    /// wire: `interface`. Standardized platform network interface hint.
    public let interface: NetworkInterfaceKind?
    /// wire: `expensive`. Whether the active route is considered expensive by the platform.
    public let expensive: Bool?
    /// wire: `metered`. Whether the active route is metered.
    public let metered: Bool?
    /// wire: `reason`. Optional platform reason string for diagnostics.
    public let reason: String?
    /// wire: `fingerprintHint`. Coarse network identity (native: a 16-hex-digit SHA-256 digest of the interface kind and the default gateway, plus the DNS servers on Android, or the cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID or a raw address.
    public let fingerprintHint: String?

    public init(available: Bool? = nil, interface: NetworkInterfaceKind? = nil, expensive: Bool? = nil, metered: Bool? = nil, reason: String? = nil, fingerprintHint: String? = nil) {
        self.available = available
        self.interface = interface
        self.expensive = expensive
        self.metered = metered
        self.reason = reason
        self.fingerprintHint = fingerprintHint
    }
}
