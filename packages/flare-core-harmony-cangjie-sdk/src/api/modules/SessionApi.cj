package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*
import flare_core_harmony_cangjie_sdk.contract.ConnectTokenRefresher

// GENERATED. Do not edit by hand.
// SDK lifecycle, authenticated session and process-level utilities.
public interface SessionApi {
    func create(requestJson: String): String
    func initSdk(requestJson: String): Unit
    func uninit(): Unit
    func login(requestJson: String): Unit
    func prepare(requestJson: String): Unit
    func connect(requestJson: String): Unit
    func updateAccessToken(requestJson: String): Unit
    // Installs (or, with null, removes) the host-managed connect token refresher: an async function returning the new connect token, or null when none can be obtained. The core calls it once after the gateway rejects a connection on authentication and waits at most 20 seconds. Not needed with SDK-managed tokens (an auth block in the init config, even an empty one).
    func setConnectTokenRefresher(refresher: ?ConnectTokenRefresher): Unit
    func setHeartbeatNatTimeout(request: SetHeartbeatNatTimeoutRequest): Unit
    func heartbeatEffectiveInterval(): HeartbeatEffectiveIntervalResponse
    func logout(): Unit
    func dispose(): Unit
    func hardReset(): Unit
    func currentUserId(): String
    func isConnected(): BooleanResponse
    func sessionActive(): BooleanResponse
    func updatePushToken(request: PushTokenInput): PushLifecycleStatus
    func clearPushToken(request: ClearPushTokenRequest): PushLifecycleStatus
    func setPushPermission(request: SetPushPermissionRequest): PushLifecycleStatus
    func reconcilePush(): PushLifecycleStatus
    func pushStatus(): PushLifecycleStatus
}
