import Foundation

/// GENERATED. Do not edit by hand.
/// Where the link supervisor is: the one connection state hosts and the Kit ConnectionNotice read.
public enum ConnectionPhase: String, Codable, Sendable {
    case idle = "idle"
    case connecting = "connecting"
    case syncing = "syncing"
    case online = "online"
    case switching = "switching"
    case reconnecting = "reconnecting"
    case waitingForNetwork = "waitingForNetwork"
    case serviceUnavailable = "serviceUnavailable"
    case actionRequired = "actionRequired"
}
