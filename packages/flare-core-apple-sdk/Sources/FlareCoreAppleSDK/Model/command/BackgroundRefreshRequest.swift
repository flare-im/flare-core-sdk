import Foundation

/// GENERATED. Do not edit by hand.
/// One background refresh the platform granted the app (iOS BGAppRefreshTask).
public struct BackgroundRefreshRequest: Codable, Sendable {
    /// wire: `budgetMs`. Time the platform grants, in milliseconds; the engine uses at most 25000 of it.
    public let budgetMs: UInt32

    public init(budgetMs: UInt32 = 0) {
        self.budgetMs = budgetMs
    }
}
