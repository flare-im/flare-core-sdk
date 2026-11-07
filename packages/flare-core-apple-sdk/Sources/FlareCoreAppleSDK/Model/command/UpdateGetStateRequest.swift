import Foundation

/// GENERATED. Do not edit by hand.
/// Reads the update state.
public struct UpdateGetStateRequest: Codable, Sendable {
    /// wire: `foreground`. The app just returned to the foreground: count that first.
    public let foreground: Bool?

    public init(foreground: Bool? = nil) {
        self.foreground = foreground
    }
}
