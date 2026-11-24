package com.flare.im.model.response

import com.flare.im.model.entity.MessageSendStage

/** GENERATED. Do not edit by hand. */
/** Send acknowledgement returned by core-sdk. */
data class SendMessageResponse(
    /** wire: `ackId`. ACK id assigned by the transport layer, if present. */
    val ackId: String = "",
    /** wire: `serverId`. Server-assigned message id. */
    val serverId: String = "",
    /** wire: `clientMsgId`. Client message id acknowledged by the server. */
    val clientMsgId: String = "",
    /** wire: `conversationId`. Conversation id. */
    val conversationId: String = "",
    /** wire: `seq`. Assigned conversation sequence. */
    val seq: Long = 0L,
    /** wire: `timestamp`. Server send time in milliseconds. */
    val timestamp: Long = 0L,
    /** wire: `success`. Whether the SDK queued the message locally or the server accepted it. Check stage for persistence. */
    val success: Boolean = false,
    /** wire: `stage`. Queued locally, accepted by the server, persisted by the server, or failed. Older engines omit this field. */
    val stage: MessageSendStage? = null,
    /** wire: `errorCode`. Core ACK error code when success is false. */
    val errorCode: Int = 0,
    /** wire: `errorMessage`. Core ACK error message when success is false. */
    val errorMessage: String = "",
)
