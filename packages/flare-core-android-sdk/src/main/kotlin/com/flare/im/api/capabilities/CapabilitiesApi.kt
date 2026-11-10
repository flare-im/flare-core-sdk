package com.flare.im.api.capabilities

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
/** Capability discovery and optional plugin dispatch through capability dispatch ops. */
interface CapabilitiesApi {
    /** preparePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `prepare_plugin_command`. Operation: `capability.prepare_plugin_command`. */
    suspend fun preparePluginCommand(request: PluginCommandRequest): Map<String, Any?>
    /** pendingPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `pending_plugin_command`. Operation: `capability.pending_plugin_command`. */
    suspend fun pendingPluginCommand(request: PluginCommandRequest): Map<String, Any?>
    /** reconcilePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `reconcile_plugin_command`. Operation: `capability.reconcile_plugin_command`. */
    suspend fun reconcilePluginCommand(request: PluginCommandRequest): Map<String, Any?>
    /** submitPluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `submit_plugin_command`. Operation: `capability.submit_plugin_command`. */
    suspend fun submitPluginCommand(request: PluginCommandRequest): Map<String, Any?>
    /** acknowledgePluginCommand maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `acknowledge_plugin_command`. Operation: `capability.acknowledge_plugin_command`. */
    suspend fun acknowledgePluginCommand(request: PluginCommandRequest): Map<String, Any?>
    /** invokePluginAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_invoke`. Operation: `capability.plugin_ui_invoke`. */
    suspend fun invokePluginAction(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** presentPluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_present`. Operation: `capability.plugin_ui_present`. */
    suspend fun presentPluginMessage(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginUiAction maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_action`. Operation: `capability.plugin_ui_action`. */
    suspend fun pluginUiAction(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** resolvePluginMessage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_resolve`. Operation: `capability.plugin_ui_resolve`. */
    suspend fun resolvePluginMessage(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginUiCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_ui_catalog`. Operation: `capability.plugin_ui_catalog`. */
    suspend fun pluginUiCatalog(request: Map<String, Any?>): Map<String, Any?>
    /** pluginComposerActions maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_composer_actions`. Operation: `capability.plugin_composer_actions`. */
    suspend fun pluginComposerActions(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginDetail maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_detail`. Operation: `capability.plugin_detail`. */
    suspend fun pluginDetail(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginPage maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_page`. Operation: `capability.plugin_page`. */
    suspend fun pluginPage(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginFileUpload maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_file_upload`. Operation: `capability.plugin_file_upload`. */
    suspend fun pluginFileUpload(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** pluginAccountEntries maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_account_entries`. Operation: `capability.plugin_account_entries`. */
    suspend fun pluginAccountEntries(request: PluginUiEvaluationRequest): Map<String, Any?>
    /** invalidatePluginCatalog maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `plugin_catalog_invalidate`. Operation: `capability.plugin_catalog_invalidate`. */
    suspend fun invalidatePluginCatalog(request: Map<String, Any?>): Unit
    /** listCapabilities maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_list`. Operation: `capability.list`. */
    suspend fun listCapabilities(request: Map<String, Any?>): Map<String, Any?>
    /** dispatchCapability maps to `flare_capability_dispatch_json` via `capability-dispatch-json`, dispatch op `capability_dispatch`. Operation: `capability.dispatch`. */
    suspend fun dispatchCapability(request: Map<String, Any?>): Map<String, Any?>
}
