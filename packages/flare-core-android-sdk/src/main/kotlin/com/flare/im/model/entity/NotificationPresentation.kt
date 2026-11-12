package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** One notification to show (or to replace in place). */
data class NotificationPresentation(
    /** wire: `body`. Body, already rendered in the app's language. */
    val body: String = "",
    /** wire: `channel`. messages, quiet, mentions or urgent (Android channel flare.<channel>). */
    val channel: String = "",
    /** wire: `collapseId`. Notification identity: one per conversation. Used as the iOS notification identifier and the Android notification tag, so a later notification for the same conversation replaces it. */
    val collapseId: String = "",
    /** wire: `conversationId`. Conversation the notification belongs to; empty for the digest notification. */
    val conversationId: String = "",
    /** wire: `count`. Unread messages the notification stands for, at least 1. */
    val count: Int = 0,
    /** wire: `messageId`. Server id of the newest message it stands for; empty for a catch-up without a loaded message and for the digest notification. */
    val messageId: String = "",
    /** wire: `seq`. Conversation seq of the newest message it stands for; 0 for the digest notification. */
    val seq: Long = 0L,
    /** wire: `sound`. Whether to play a sound; a silent replacement never sounds. */
    val sound: Boolean = false,
    /** wire: `surface`. system (an OS notification) or inApp (a banner inside the running app). */
    val surface: String = "",
    /** wire: `threadId`. Grouping key in the notification centre. */
    val threadId: String = "",
    /** wire: `title`. Title, already rendered in the app's language. */
    val title: String = "",
)
