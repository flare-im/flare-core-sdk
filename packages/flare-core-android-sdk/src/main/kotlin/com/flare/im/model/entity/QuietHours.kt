package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Do-not-disturb hours, in the device's local time. */
data class QuietHours(
    /** wire: `allowMentions`. Whether messages that mention the user still ring inside the window. */
    val allowMentions: Boolean = false,
    /** wire: `endMinute`. End, minute of the day (0..1439), exclusive. Equal to the start: all day. Smaller than the start: the window crosses midnight. */
    val endMinute: Int = 0,
    /** wire: `startMinute`. Start, minute of the day (0..1439), inclusive. */
    val startMinute: Int = 0,
    /** wire: `weekdays`. Days the window starts on: bit0 Monday .. bit6 Sunday; 0 means every day. */
    val weekdays: Int = 0,
)
