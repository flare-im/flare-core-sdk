package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Optional upload options. Omitted chunkSize defaults to 256 KiB; omitted purpose defaults to general. options may contain purpose alone. No arbitrary Public access flag exists.
public class MediaUploadOptions {
    // wire: `chunkSize`. Optional. Optional positive part size, in bytes; absent preserves the existing default.
    public let chunkSize: ?UInt32
    // wire: `purpose`. Optional. Explicit avatar publication intent. General uploads stay private. Avatar returns stable unsigned url/cdnUrl after real image validation.
    public let purpose: ?MediaUploadPurpose

    public init(chunkSize!: ?UInt32, purpose!: ?MediaUploadPurpose) {
        this.chunkSize = chunkSize
        this.purpose = purpose
    }
}
