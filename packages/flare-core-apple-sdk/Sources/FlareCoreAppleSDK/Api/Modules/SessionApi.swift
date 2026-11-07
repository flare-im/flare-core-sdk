import Foundation

/// GENERATED. Do not edit by hand.
/// SDK lifecycle, authenticated session and process-level utilities.
public protocol SessionApiProtocol: AnyObject {
    func create(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func `init`(_ request: [String: AnySendable]) async throws -> Void
    func uninit() async throws -> Void
    func login(_ request: [String: AnySendable]) async throws -> Void
    func prepare(_ request: [String: AnySendable]) async throws -> Void
    func connect(_ request: [String: AnySendable]) async throws -> Void
    func updateAccessToken(_ request: [String: AnySendable]) async throws -> Void
    /// Installs (or, with null, removes) the host-managed connect token refresher: an async function returning the new connect token, or null when none can be obtained. The core calls it once after the gateway rejects a connection on authentication and waits at most 20 seconds. Not needed with SDK-managed tokens (an auth block in the init config, even an empty one).
    func setConnectTokenRefresher(_ refresher: ConnectTokenRefresher?) async throws
    func setHeartbeatNatTimeout(_ request: SetHeartbeatNatTimeoutRequest) async throws -> Void
    func heartbeatEffectiveInterval() async throws -> HeartbeatEffectiveIntervalResponse
    func logout() async throws -> Void
    func dispose() async throws -> Void
    func hardReset() async throws -> Void
    func currentUserId() async throws -> [String: AnySendable]
    func isConnected() async throws -> Bool
    func sessionActive() async throws -> Bool
    func updatePushToken(_ request: PushTokenInput) async throws -> PushLifecycleStatus
    func clearPushToken(_ request: ClearPushTokenRequest) async throws -> PushLifecycleStatus
    func setPushPermission(_ request: SetPushPermissionRequest) async throws -> PushLifecycleStatus
    func reconcilePush() async throws -> PushLifecycleStatus
    func pushStatus() async throws -> PushLifecycleStatus
}
