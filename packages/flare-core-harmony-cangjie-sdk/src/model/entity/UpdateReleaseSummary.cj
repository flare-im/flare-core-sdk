package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The release on offer.
public class UpdateReleaseSummary {
    // wire: `releaseId`. Release id.
    public let releaseId: String
    // wire: `version`. Display version.
    public let version: String
    // wire: `build`. Build number.
    public let build: UInt64
    // wire: `notes`. Release notes, already in the chosen language.
    public let notes: String
    // wire: `sizeBytes`. Optional. Size to download; absent for a store.
    public let sizeBytes: ?UInt64
    // wire: `mandatory`. Forced update.
    public let mandatory: Bool
    // wire: `recommended`. Recommended update.
    public let recommended: Bool
    // wire: `kind`. store, package, webBundle or desktop.
    public let kind: String

    public init(releaseId!: String, version!: String, build!: UInt64, notes!: String, sizeBytes!: ?UInt64, mandatory!: Bool, recommended!: Bool, kind!: String) {
        this.releaseId = releaseId
        this.version = version
        this.build = build
        this.notes = notes
        this.sizeBytes = sizeBytes
        this.mandatory = mandatory
        this.recommended = recommended
        this.kind = kind
    }
}
