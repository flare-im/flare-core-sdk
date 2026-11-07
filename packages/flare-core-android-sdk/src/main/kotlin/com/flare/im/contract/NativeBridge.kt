package com.flare.im.contract

import com.flare.im.bridge.FlareSdkException

/** GENERATED. Do not edit by hand. */
/**
 * Host-managed connect token refresh: returns the new connect token, or null when none can be
 * obtained. The core waits at most 20 seconds.
 */
typealias ConnectTokenRefresher = suspend () -> String?

/** Platform runtimes implement this bridge using FFI, JNI, N-API, WASM or host IPC. */
interface NativeBridge {
    suspend fun <T> invoke(descriptor: NativeCallDescriptor, request: Any? = null): T

    /**
     * Installs (or, with null, removes) the connect token refresher: registers the native
     * trampoline with flare_sdk_set_connect_token_refresher and answers every request with
     * flare_sdk_complete_connect_token_refresh.
     */
    suspend fun setConnectTokenRefresher(refresher: ConnectTokenRefresher?) {
        // Bridges without a refresh channel (test doubles) report capabilityUnavailable.
        throw FlareSdkException(
            code = SdkErrorCodes.CAPABILITYUNAVAILABLE,
            message = "This bridge cannot call back for a connect token.",
            operation = SdkOperations.SDK_SET_CONNECT_TOKEN_REFRESHER,
        )
    }
}
