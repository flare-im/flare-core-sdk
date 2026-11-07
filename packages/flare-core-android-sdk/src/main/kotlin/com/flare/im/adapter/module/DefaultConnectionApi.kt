package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.connection.ConnectionApi
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
class DefaultConnectionApi(
    private val bridge: NativeBridge,
) : ConnectionApi {

    override suspend fun getStatus(): ConnectionStatus {
        return connectionStatusFromJson(invokeMap(bridge, NativeCallMap.CONNECTION_GET_STATUS))
    }

    override suspend fun reconnectNow(): Unit {
        invokeUnit(bridge, NativeCallMap.CONNECTION_RECONNECT_NOW)
    }

    override suspend fun disconnect(): Unit {
        invokeUnit(bridge, NativeCallMap.CONNECTION_DISCONNECT)
    }

    override suspend fun getServerClock(): ServerClockResponse {
        return serverClockResponseFromJson(invokeMap(bridge, NativeCallMap.CONNECTION_SERVER_CLOCK))
    }

    override suspend fun notifyNetworkChange(request: NetworkChangeRequest): Unit {
        invokeUnit(bridge, NativeCallMap.CONNECTION_NOTIFY_NETWORK_CHANGE, networkChangeRequestToMap(request))
    }
}
