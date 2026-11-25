package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** Optional upload options. Omitted chunkSize defaults to 256 KiB; omitted purpose defaults to general. options may contain purpose alone. No arbitrary Public access flag exists. */
data class MediaUploadOptions(
    /** wire: `transferId`.  */
    val transferId: String? = null,
    /** wire: `chunkSize`. Optional positive part size, in bytes; absent preserves the existing default. */
    val chunkSize: Int? = null,
    /** wire: `purpose`. Explicit avatar publication intent. General uploads stay private. Avatar returns stable unsigned url/cdnUrl after real image validation. */
    val purpose: MediaUploadPurpose? = null,
)
