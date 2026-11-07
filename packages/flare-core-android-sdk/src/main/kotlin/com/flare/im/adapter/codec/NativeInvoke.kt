package com.flare.im.adapter.codec

import com.flare.im.adapter.module.DefaultEventsApi
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallDescriptor
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
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
internal suspend fun invokeUnit(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
) {
    bridge.invoke<Unit>(descriptor, request)
}

internal suspend fun invokeMap(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): Map<String, Any?> = bridge.invoke(descriptor, request)

internal suspend fun invokeBool(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): Boolean = bridge.invoke(descriptor, request)

internal suspend fun invokeMessage(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): Message {
    val raw = invokeMap(bridge, descriptor, request)
    return messageFromJson(raw["message"] ?: raw)
}

internal suspend fun invokeSendAck(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): SendMessageResponse = sendAckFromJson(invokeMap(bridge, descriptor, request))

internal suspend fun invokeListConversations(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): ListConversationsResponse = listConversationsResponseFromJson(invokeMap(bridge, descriptor, request))

internal suspend fun invokeListMessages(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): ListMessagesResponse = listMessagesResponseFromJson(invokeMap(bridge, descriptor, request))

internal suspend fun invokeConversation(
    bridge: NativeBridge,
    descriptor: NativeCallDescriptor,
    request: Any? = null,
): Conversation {
    val raw = invokeMap(bridge, descriptor, request)
    val conversations = listOfMaps(raw["conversations"])
    if (conversations.isNotEmpty()) {
        return conversationFromJson(conversations.first())
    }
    return conversationFromJson(raw)
}

internal fun sdkErrorPayloadFromThrowable(
    error: Throwable,
    operation: String,
): SdkErrorPayload = SdkErrorPayload(
    code = "internal",
    message = error.message ?: operation,
    operation = operation,
    retryable = false,
    details = mapOf("type" to error::class.java.name),
)

internal fun userIdFromRequest(request: Map<String, Any?>): String? =
    request["userId"]?.toString()

internal fun DefaultEventsApi.emitLifecycleEvent(
    name: LifecycleEventName,
    operation: String,
    userId: String? = null,
    error: SdkErrorPayload? = null,
) {
    emit(
        LifecycleEvent(
            name = name,
            operation = operation,
            userId = userId,
            error = error,
        ),
    )
}
