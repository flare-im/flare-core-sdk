package com.flare.im.model.command

/** GENERATED. Do not edit by hand. */
/** A prompt really appeared. */
data class UpdateMarkPromptedRequest(
    /** wire: `build`. Build the prompt is about; absent when a forced update has no release yet. */
    val build: Long? = null,
    /** wire: `form`. sheet, modal or fullscreen. */
    val form: String = "",
)
