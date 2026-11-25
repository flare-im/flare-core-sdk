package com.flare.im.model.response

import com.flare.im.model.entity.Message

/** GENERATED. Do not edit by hand. */
/** A local lookup within one conversation and sender. Missing or ambiguous messages have no value. */
data class MessageByKeyResponse(
    /** wire: `message`.  */
    val message: Message? = null,
)
