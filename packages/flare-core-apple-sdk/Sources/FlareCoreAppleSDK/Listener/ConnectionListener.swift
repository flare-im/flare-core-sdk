import Foundation

/// GENERATED. Do not edit by hand.
/// Connection listener callbacks.
public protocol ConnectionEventListener: AnyObject {
    /// The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged.
    func onConnectionStatusChanged(_ event: ConnectionStatus)
}

public extension ConnectionEventListener {
    func onConnectionStatusChanged(_ event: ConnectionStatus) {}
}
