import Foundation

/// GENERATED. Do not edit by hand.
/// The answer of update.getResources.
public struct UpdateResources: Codable, Sendable {
    /// wire: `packs`. Packs of this run, sorted by id.
    public let packs: [UpdateResourcePack]

    public init(packs: [UpdateResourcePack] = []) {
        self.packs = packs
    }
}
