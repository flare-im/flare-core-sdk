package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.capabilities.CapabilitiesApi
import com.flare.im.callback.*
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallMap
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
class DefaultCapabilitiesApi(
    private val bridge: NativeBridge,
) : CapabilitiesApi {

    override suspend fun preparePluginCommand(request: PluginCommandRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PREPARE_PLUGIN_COMMAND, pluginCommandRequestToMap(request))
    }

    override suspend fun pendingPluginCommand(request: PluginCommandRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PENDING_PLUGIN_COMMAND, pluginCommandRequestToMap(request))
    }

    override suspend fun reconcilePluginCommand(request: PluginCommandRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_RECONCILE_PLUGIN_COMMAND, pluginCommandRequestToMap(request))
    }

    override suspend fun submitPluginCommand(request: PluginCommandRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_SUBMIT_PLUGIN_COMMAND, pluginCommandRequestToMap(request))
    }

    override suspend fun acknowledgePluginCommand(request: PluginCommandRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_ACKNOWLEDGE_PLUGIN_COMMAND, pluginCommandRequestToMap(request))
    }

    override suspend fun invokePluginAction(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_UI_INVOKE, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun presentPluginMessage(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_UI_PRESENT, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun pluginUiAction(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_UI_ACTION, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun resolvePluginMessage(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_UI_RESOLVE, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun pluginUiCatalog(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_UI_CATALOG, request)
    }

    override suspend fun pluginComposerActions(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_COMPOSER_ACTIONS, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun pluginDetail(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_DETAIL, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun pluginPage(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_PAGE, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun pluginAccountEntries(request: PluginUiEvaluationRequest): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_PLUGIN_ACCOUNT_ENTRIES, pluginUiEvaluationRequestToMap(request))
    }

    override suspend fun invalidatePluginCatalog(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CAPABILITY_PLUGIN_CATALOG_INVALIDATE, request)
    }

    override suspend fun listCapabilities(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_LIST, request)
    }

    override suspend fun listUserCapabilities(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_LIST_USER, request)
    }

    override suspend fun dispatchCapability(request: Map<String, Any?>): Map<String, Any?> {
        return invokeMap(bridge, NativeCallMap.CAPABILITY_DISPATCH, request)
    }

    override suspend fun grantCapability(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CAPABILITY_GRANT, request)
    }

    override suspend fun revokeCapability(request: Map<String, Any?>): Unit {
        invokeUnit(bridge, NativeCallMap.CAPABILITY_REVOKE, request)
    }
}
