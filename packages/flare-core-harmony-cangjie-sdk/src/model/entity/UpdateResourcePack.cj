package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One verified resource pack. Data only; the Kit and the host interpret it.
public class UpdateResourcePack {
    // wire: `id`. Pack id.
    public let id: String
    // wire: `kind`. strings, tokens, emoji or help.
    public let kind: String
    // wire: `packVersion`. Pack version.
    public let packVersion: UInt64
    // wire: `contentJson`. The pack file as text, a flare.resource.v1 document.
    public let contentJson: String

    public init(id!: String, kind!: String, packVersion!: UInt64, contentJson!: String) {
        this.id = id
        this.kind = kind
        this.packVersion = packVersion
        this.contentJson = contentJson
    }
}
