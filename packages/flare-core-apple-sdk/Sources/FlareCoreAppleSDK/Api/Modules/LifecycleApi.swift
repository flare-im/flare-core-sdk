import Foundation

/// GENERATED. Do not edit by hand.
/// Platform lifecycle signals the core needs (foreground and background).
public protocol LifecycleApiProtocol: AnyObject {
    func setAppState(_ request: SetAppStateRequest) async throws -> Void
}
