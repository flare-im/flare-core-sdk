package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** One verified resource pack. Data only; the Kit and the host interpret it. */
data class UpdateResourcePack(
    /** wire: `id`. Pack id. */
    val id: String = "",
    /** wire: `kind`. strings, tokens, emoji or help. */
    val kind: String = "",
    /** wire: `packVersion`. Pack version. */
    val packVersion: Long = 0L,
    /** wire: `contentJson`. The pack file as text, a flare.resource.v1 document. */
    val contentJson: String = "",
)
