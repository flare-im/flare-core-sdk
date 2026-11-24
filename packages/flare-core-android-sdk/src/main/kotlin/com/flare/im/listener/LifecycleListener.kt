package com.flare.im.listener

import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
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
/** Lifecycle listener callbacks. */
interface LifecycleEventListener {
    /** SDK initialization has started. */
    fun onInitializing(event: LifecycleEvent) {}
    /** SDK initialization completed successfully. */
    fun onInitialized(event: LifecycleEvent) {}
    /** SDK initialization failed. */
    fun onInitFailed(event: LifecycleEvent) {}
    /** SDK login completed successfully. */
    fun onLoginSucceeded(event: LifecycleEvent) {}
    /** SDK login failed. */
    fun onLoginFailed(event: LifecycleEvent) {}
    /** The current SDK session logged out. */
    fun onLoggedOut(event: LifecycleEvent) {}
    /** The SDK client has been disposed. */
    fun onDisposed(event: LifecycleEvent) {}
}
