import Foundation

/// GENERATED. Do not edit by hand.
/// A local lookup within one conversation and sender. Missing or ambiguous messages have no value.
public struct MessageByKeyResponse: Sendable {
    /// wire: `message`. 
    public let message: Message?

    public init(message: Message? = nil) {
        self.message = message
    }
}
