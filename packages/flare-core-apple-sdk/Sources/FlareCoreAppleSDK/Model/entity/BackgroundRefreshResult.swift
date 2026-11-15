import Foundation

/// GENERATED. Do not edit by hand.
/// How a background refresh ended.
public struct BackgroundRefreshResult: Codable, Sendable {
    /// wire: `completed`. The link came up and the incremental sync finished within the budget. False when the budget ran out or no session could connect.
    public let completed: Bool

    public init(completed: Bool = false) {
        self.completed = completed
    }
}
