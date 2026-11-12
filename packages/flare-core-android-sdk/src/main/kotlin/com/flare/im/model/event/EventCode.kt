package com.flare.im.model.event

/** GENERATED. Do not edit by hand. */
object EventCode {
    const val CONNECTION_SYNC_STATE_CHANGED: Int = 1005
    const val CONNECTION_STATUS: Int = 1010
    const val ACCESS_SWITCHED: Int = 1011
    const val ACCESS_CHANGED: Int = 1012
    const val UPDATE_STATE: Int = 1013
    const val MESSAGE_RECEIVED: Int = 2001
    const val MESSAGE_RECEIVED_BATCH: Int = 2002
    const val MESSAGE_SEND_ACK: Int = 2003
    const val MESSAGE_SEND_FAILED: Int = 2004
    const val MESSAGE_RECALLED: Int = 2005
    const val MESSAGE_TYPING: Int = 2006
    const val MESSAGE_EDITED: Int = 2008
    const val MESSAGE_REACTION_CHANGED: Int = 2009
    const val MESSAGE_DELETED: Int = 2010
    const val MESSAGE_READ_RECEIPT: Int = 2011
    const val MESSAGE_RETENTION_SCHEDULED: Int = 2012
    const val MESSAGE_RETENTION_EXPIRED: Int = 2013
    const val MESSAGE_RETENTION_PURGED: Int = 2014
    const val MESSAGE_PINNED: Int = 2015
    const val MESSAGE_UNPINNED: Int = 2016
    const val MESSAGE_MARKED: Int = 2017
    const val MESSAGE_UNMARKED: Int = 2018
    const val MESSAGE_PRESENCE_CHANGED: Int = 2019
    const val MESSAGE_CUSTOM: Int = 2020
    const val MESSAGE_TYPING_AGGREGATE: Int = 2021
    const val MESSAGE_PLUGIN_STATE_CHANGED: Int = 2022
    const val MESSAGE_READ_SUMMARIES_CHANGED: Int = 2023
    const val CONVERSATION_SYNCED: Int = 3001
    const val CONVERSATION_CREATED: Int = 3002
    const val CONVERSATION_UPDATED: Int = 3003
    const val CONVERSATION_UNREAD_COUNT_CHANGED: Int = 3004
    const val CONVERSATION_DELETED: Int = 3005
    const val NOTIFICATION_RECEIVED: Int = 3501
    const val NOTIFICATION_PRESENT: Int = 3503
    const val NOTIFICATION_CLEAR: Int = 3504
    const val NOTIFICATION_BADGE: Int = 3505
    const val SYNC_STARTED: Int = 4001
    const val SYNC_FINISHED: Int = 4002
    const val SYNC_FAILED: Int = 4003
    const val SYNC_PROGRESS: Int = 4004
    const val SYNC_TASK_COMPLETED: Int = 4005
    const val SYNC_STATE_CHANGED: Int = 4006
    const val SYNC_RESYNC_NEEDED: Int = 4007
    const val SYNC_READINESS: Int = 4008
    const val EXTENSION: Int = 5001
    const val VIEW_UPDATED: Int = 6001
    const val PLUGIN_REALTIME: Int = 7001
    const val PLUGIN_CATALOG_CHANGED: Int = 7002
}
