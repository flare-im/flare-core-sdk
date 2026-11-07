package com.flare.im.api.presence

import com.flare.im.callback.*
import com.flare.im.listener.*
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
/** Presence and input state. */
interface PresenceApi {
    /** getUserPresence maps to `flare_sdk_get_user_presence` via `ffi-symbol`. Operation: `presence.get`. */
    suspend fun getUserPresence(request: Map<String, Any?>): Map<String, Any?>
    /** batchGetUserPresence maps to `flare_sdk_batch_get_user_presence` via `ffi-symbol`. Operation: `presence.batch_get`. */
    suspend fun batchGetUserPresence(request: Map<String, Any?>): Map<String, Any?>
    /** subscribeUserPresence maps to `flare_sdk_subscribe_user_presence` via `ffi-symbol`. Operation: `presence.subscribe`. */
    suspend fun subscribeUserPresence(request: Map<String, Any?>): Unit
}
