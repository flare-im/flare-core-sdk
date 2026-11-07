import Foundation

/// GENERATED. Do not edit by hand.
/// One verified resource pack. Data only; the Kit and the host interpret it.
public struct UpdateResourcePack: Codable, Sendable {
    /// wire: `id`. Pack id.
    public let id: String
    /// wire: `kind`. strings, tokens, emoji or help.
    public let kind: String
    /// wire: `packVersion`. Pack version.
    public let packVersion: UInt64
    /// wire: `contentJson`. The pack file as text, a flare.resource.v1 document.
    public let contentJson: String

    public init(id: String = "", kind: String = "", packVersion: UInt64 = 0, contentJson: String = "") {
        self.id = id
        self.kind = kind
        self.packVersion = packVersion
        self.contentJson = contentJson
    }
}
