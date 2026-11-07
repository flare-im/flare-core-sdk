import Foundation

/// GENERATED. Do not edit by hand.
/// Checks for an update.
public struct UpdateCheckRequest: Codable, Sendable {
    /// wire: `manual`. The user asked: no frequency limit, and a failure lands in UpdateStatus.error.
    public let manual: Bool

    public init(manual: Bool = false) {
        self.manual = manual
    }
}
