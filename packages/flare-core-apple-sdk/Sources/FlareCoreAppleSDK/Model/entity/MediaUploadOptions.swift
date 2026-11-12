import Foundation

/// GENERATED. Do not edit by hand.
/// Optional upload options. Omitted chunkSize defaults to 256 KiB; omitted purpose defaults to general. options may contain purpose alone. No arbitrary Public access flag exists.
public struct MediaUploadOptions: Codable, Sendable {
    /// wire: `chunkSize`. Optional positive part size, in bytes; absent preserves the existing default.
    public let chunkSize: UInt32?
    /// wire: `purpose`. Explicit avatar publication intent. General uploads stay private. Avatar returns stable unsigned url/cdnUrl after real image validation.
    public let purpose: MediaUploadPurpose?

    public init(chunkSize: UInt32? = nil, purpose: MediaUploadPurpose? = nil) {
        self.chunkSize = chunkSize
        self.purpose = purpose
    }
}
