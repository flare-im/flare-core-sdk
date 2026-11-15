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
/** Plugin listener callbacks. */
interface PluginEventListener {
    /** A plugin delivered a realtime packet to this user's online connections (im.realtime.deliver): online only, at most once, never stored. Expired packets and payloads that are not JSON objects never arrive. Route by pluginId and packetType. */
    fun onPluginRealtime(event: PluginRealtimeEvent) {}
    /** The tenant's plugin catalog changed (a plugin enabled, disabled or reconfigured). The SDK has already invalidated its plugin catalog; read plugin entries and configuration again. Arrives a random 0-3 s after the notice, with the notices of 3 s merged into one. */
    fun onPluginCatalogChanged(event: PluginCatalogChangedEvent) {}
    /** The engine asks the host to do its part of a plugin host capability (method consent, captureDocument, pickFile, confirmPayment or locateOnce). Show the kit's screen for it and answer with completePluginCapabilityRequest({requestId, result}); the engine waits up to 10 minutes. */
    fun onPluginCapabilityRequest(event: PluginCapabilityRequestEvent) {}
    /** Something for an open web bundle page: post envelope (a bridge event) to the page as it is; close the page when close is set (withdrawn, suspended, disabled, replaced, evicted or signedOut). */
    fun onPluginBundleEvent(event: PluginBundleEvent) {}
}
