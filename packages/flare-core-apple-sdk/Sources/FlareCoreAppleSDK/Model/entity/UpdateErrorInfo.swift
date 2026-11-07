import Foundation

/// GENERATED. Do not edit by hand.
/// Why the last update action did not go through.
public struct UpdateErrorInfo: Codable, Sendable {
    /// wire: `code`. update.* code.
    public let code: String
    /// wire: `retryable`. Retrying can help.
    public let retryable: Bool
    /// wire: `fallbackUrl`. Page to send the user to; absent on the web.
    public let fallbackUrl: String?

    public init(code: String = "", retryable: Bool = false, fallbackUrl: String? = nil) {
        self.code = code
        self.retryable = retryable
        self.fallbackUrl = fallbackUrl
    }
}
