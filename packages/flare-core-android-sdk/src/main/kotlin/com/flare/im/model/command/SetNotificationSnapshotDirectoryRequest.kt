package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** Where the engine keeps the notification snapshot an iOS notification service extension reads. */
data class SetNotificationSnapshotDirectoryRequest(
    /** wire: `directory`. Directory shared with the extension (the App Group container on iOS). The engine writes snapshot.json there and reads the extension's receipts.log from it. Absent: stop writing; files already there are left alone. */
    val directory: String? = null,
)
