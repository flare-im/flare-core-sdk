import Foundation

/// GENERATED. Do not edit by hand.
/// The release on offer.
public struct UpdateReleaseSummary: Codable, Sendable {
    /// wire: `releaseId`. Release id.
    public let releaseId: String
    /// wire: `version`. Display version.
    public let version: String
    /// wire: `build`. Build number.
    public let build: UInt64
    /// wire: `notes`. Release notes, already in the chosen language.
    public let notes: [String]
    /// wire: `sizeBytes`. Size to download; absent for a store.
    public let sizeBytes: UInt64?
    /// wire: `mandatory`. Forced update.
    public let mandatory: Bool
    /// wire: `recommended`. Recommended update.
    public let recommended: Bool
    /// wire: `kind`. store, package, webBundle or desktop.
    public let kind: String

    public init(releaseId: String = "", version: String = "", build: UInt64 = 0, notes: [String] = [], sizeBytes: UInt64? = nil, mandatory: Bool = false, recommended: Bool = false, kind: String = "") {
        self.releaseId = releaseId
        self.version = version
        self.build = build
        self.notes = notes
        self.sizeBytes = sizeBytes
        self.mandatory = mandatory
        self.recommended = recommended
        self.kind = kind
    }
}
