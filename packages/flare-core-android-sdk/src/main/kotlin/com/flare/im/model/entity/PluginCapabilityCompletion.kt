package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** The host's answer to a plugin.capability_request event. */
data class PluginCapabilityCompletion(
    /** wire: `requestId`. The event's requestId. */
    val requestId: Long = 0L,
    /** wire: `result`. consent: {granted}; captureDocument and pickFile: {file: {fileName, contentType, bytes: [0..255]}} (a document photo compressed, without EXIF); confirmPayment: {confirmation: {...}} (the proof the order's operation takes, at most 4 KiB); locateOnce: {location: {latitude, longitude, accuracyM?}}. Any of them may instead be {cancelled: true} (the viewer backed out) or {unavailable: true} (the host could not); absent counts as unavailable. */
    val result: Map<String, Any?>? = null,
)
