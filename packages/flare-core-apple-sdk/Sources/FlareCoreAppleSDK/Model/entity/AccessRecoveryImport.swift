import Foundation

/// GENERATED. Do not edit by hand.
/// Result of importing a recovery link.
public struct AccessRecoveryImport: Codable, Sendable {
    /// wire: `outcome`. adopted, unchanged (this link was already imported) or rejected.
    public let outcome: String
    /// wire: `code`. Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature.
    public let code: String?
    /// wire: `serial`. Directory serial after the import.
    public let serial: UInt64

    public init(outcome: String = "", code: String? = nil, serial: UInt64 = 0) {
        self.outcome = outcome
        self.code = code
        self.serial = serial
    }
}
