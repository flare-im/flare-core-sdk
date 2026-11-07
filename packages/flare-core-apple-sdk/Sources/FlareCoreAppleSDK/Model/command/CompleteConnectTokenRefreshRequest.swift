import Foundation

/// GENERATED. Do not edit by hand.
/// Answer to one connect token refresh request.
public struct CompleteConnectTokenRefreshRequest: Codable, Sendable {
    /// wire: `requestId`. Request id the core asked with.
    public let requestId: UInt64
    /// wire: `token`. The new connect token; omitted or empty when none could be obtained.
    public let token: String?

    public init(requestId: UInt64 = 0, token: String? = nil) {
        self.requestId = requestId
        self.token = token
    }
}
