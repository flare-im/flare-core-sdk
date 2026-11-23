package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Typed delta emitted by core observable views. A timeline delta works by the message timelineKey (canonical server identity for confirmed rows; ACK migrates the local row identity): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list. */
data class ViewDelta(
    /** wire: `viewType`. Delta tag: timeline or conversationList. */
    val viewType: String = "",
    /** wire: `prepend`. Timeline: older rows to put before the first row, in timeline order. */
    val prepend: List<Message>? = null,
    /** wire: `append`. Timeline: newer rows to put after the last row, in timeline order. */
    val append: List<Message>? = null,
    /** wire: `upsert`. Timeline: new content of rows already in the window, replaced in place by row key. */
    val upsert: List<Message>? = null,
    /** wire: `remove`. Timeline: row keys leaving the window. */
    val remove: List<String>? = null,
    /** wire: `reorder`. Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express. */
    val reorder: List<String>? = null,
    /** wire: `hasOlder`. Timeline: whether more visible messages exist below the window. */
    val hasOlder: Boolean? = null,
    /** wire: `hasNewer`. Timeline: whether more messages exist above the window. */
    val hasNewer: Boolean? = null,
    /** wire: `attachedToLatest`. Timeline: whether the window is attached to the latest. */
    val attachedToLatest: Boolean? = null,
    /** wire: `conversation`. Timeline: the conversation header, only when it changed. */
    val conversation: Conversation? = null,
    /** wire: `ops`. Conversation list: ordered indexed operations. */
    val ops: List<ViewDeltaOp>? = null,
    /** wire: `totalUnread`. Conversation list: latest total unread value. */
    val totalUnread: Long? = null,
    /** wire: `syncState`. Conversation list: latest sync state. */
    val syncState: String? = null,
)
