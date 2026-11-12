package com.flare.im.api.session

import com.flare.im.callback.*
import com.flare.im.listener.*
import com.flare.im.contract.ConnectTokenRefresher
import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
import com.flare.im.model.event.access.*
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.plugin.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
/** SDK lifecycle, authenticated session and process-level utilities. */
interface SessionApi {
    /** create maps to `flare_sdk_create` via `ffi-symbol`. Operation: `sdk.create`. */
    suspend fun create(request: Map<String, Any?>): Map<String, Any?>
    /** init maps to `flare_sdk_init` via `ffi-symbol`. Operation: `sdk.init`. */
    suspend fun init(request: Map<String, Any?>): Unit
    /** uninit maps to `flare_sdk_uninit` via `ffi-symbol`. Operation: `sdk.uninit`. */
    suspend fun uninit(): Unit
    /** login maps to `flare_sdk_login` via `ffi-symbol`. Operation: `sdk.login`. */
    suspend fun login(request: Map<String, Any?>): Unit
    /** prepare maps to `flare_sdk_prepare` via `ffi-symbol`. Operation: `sdk.prepare`. */
    suspend fun prepare(request: Map<String, Any?>): Unit
    /** connect maps to `flare_sdk_connect` via `ffi-symbol`. Operation: `sdk.connect`. */
    suspend fun connect(request: Map<String, Any?>): Unit
    /** updateAccessToken maps to `flare_sdk_update_access_token` via `ffi-symbol`. Operation: `sdk.update_access_token`. */
    suspend fun updateAccessToken(request: Map<String, Any?>): Unit
    /** Installs (or, with null, removes) the host-managed connect token refresher: an async function returning the new connect token, or null when none can be obtained. The core calls it once after the gateway rejects a connection on authentication and waits at most 20 seconds. Not needed with SDK-managed tokens (an auth block in the init config, even an empty one). */
    suspend fun setConnectTokenRefresher(refresher: ConnectTokenRefresher?): Unit
    /** setHeartbeatNatTimeout maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_heartbeat_nat_timeout`. */
    suspend fun setHeartbeatNatTimeout(request: SetHeartbeatNatTimeoutRequest): Unit
    /** heartbeatEffectiveInterval maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.heartbeat_effective_interval`. */
    suspend fun heartbeatEffectiveInterval(): HeartbeatEffectiveIntervalResponse
    /** logout maps to `flare_sdk_logout` via `ffi-symbol`. Operation: `sdk.logout`. */
    suspend fun logout(): Unit
    /** dispose maps to `flare_sdk_release` via `ffi-symbol`. Operation: `sdk.dispose`. */
    suspend fun dispose(): Unit
    /** hardReset maps to `flare_sdk_hard_reset` via `ffi-symbol`. Operation: `sdk.hard_reset`. */
    suspend fun hardReset(): Unit
    /** currentUserId maps to `flare_sdk_current_user_id` via `ffi-symbol`. Operation: `sdk.current_user_id`. */
    suspend fun currentUserId(): Map<String, Any?>
    /** isConnected maps to `flare_sdk_is_connected` via `ffi-symbol`. Operation: `sdk.is_connected`. */
    suspend fun isConnected(): Boolean
    /** sessionActive maps to `flare_sdk_session_active` via `ffi-symbol`. Operation: `sdk.session_active`. */
    suspend fun sessionActive(): Boolean
    /** updatePushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.update_push_token`. */
    suspend fun updatePushToken(request: PushTokenInput): PushLifecycleStatus
    /** clearPushToken maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.clear_push_token`. */
    suspend fun clearPushToken(request: ClearPushTokenRequest): PushLifecycleStatus
    /** setPushPermission maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.set_push_permission`. */
    suspend fun setPushPermission(request: SetPushPermissionRequest): PushLifecycleStatus
    /** reconcilePush maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.reconcile_push`. */
    suspend fun reconcilePush(): PushLifecycleStatus
    /** pushStatus maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.push_status`. */
    suspend fun pushStatus(): PushLifecycleStatus
    /** handleRemoteMessage maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.handle_remote_message`. */
    suspend fun handleRemoteMessage(request: HandleRemoteMessageRequest): RemoteMessageOutcome
    /** resolveNotificationTap maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `sdk.resolve_notification_tap`. */
    suspend fun resolveNotificationTap(request: ResolveNotificationTapRequest): NotificationTapResult
}
