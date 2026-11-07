import Foundation

/// GENERATED. Do not edit by hand.
/// Download progress.
public struct UpdateProgress: Codable, Sendable {
    /// wire: `received`. Bytes received.
    public let received: UInt64
    /// wire: `total`. Bytes in all.
    public let total: UInt64

    public init(received: UInt64 = 0, total: UInt64 = 0) {
        self.received = received
        self.total = total
    }
}
