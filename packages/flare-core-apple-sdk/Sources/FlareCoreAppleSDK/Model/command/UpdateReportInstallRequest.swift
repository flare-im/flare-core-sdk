import Foundation

/// GENERATED. Do not edit by hand.
/// What the platform package did with the install plan.
public struct UpdateReportInstallRequest: Codable, Sendable {
    /// wire: `outcome`. started, completed, cancelled or failed.
    public let outcome: String
    /// wire: `code`. update.* code when outcome is failed.
    public let code: String?

    public init(outcome: String = "", code: String? = nil) {
        self.outcome = outcome
        self.code = code
    }
}
