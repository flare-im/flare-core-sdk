package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Platform network-change notification. The link supervisor alone decides whether and how to reconnect.
public class NetworkChangeRequest {
    // wire: `available`. Optional. Whether a network route is currently available. Omitted means available.
    public let available: ?Bool
    // wire: `interface`. Optional. Standardized platform network interface hint.
    public let interfaceValue: ?NetworkInterfaceKind
    // wire: `expensive`. Optional. Whether the active route is considered expensive by the platform.
    public let expensive: ?Bool
    // wire: `metered`. Optional. Whether the active route is metered.
    public let metered: ?Bool
    // wire: `reason`. Optional. Optional platform reason string for diagnostics.
    public let reason: ?String
    // wire: `fingerprintHint`. Optional. Coarse network identity (native: Wi-Fi gateway prefix or cellular MCC-MNC; web: navigator.connection.type). Hashed locally with interface into the network fingerprint that keys access point health; never sent anywhere. Never pass an SSID.
    public let fingerprintHint: ?String

    public init(available!: ?Bool, interfaceValue!: ?NetworkInterfaceKind, expensive!: ?Bool, metered!: ?Bool, reason!: ?String, fingerprintHint!: ?String) {
        this.available = available
        this.interfaceValue = interfaceValue
        this.expensive = expensive
        this.metered = metered
        this.reason = reason
        this.fingerprintHint = fingerprintHint
    }
}
