import Foundation

/// GENERATED. Do not edit by hand.
/// Select the IM connection transport.
public struct SetProtocolModeRequest: Codable, Sendable {
    /// wire: `mode`. Transport mode: ws, quic, or race.
    public let mode: String

    public init(mode: String = "") {
        self.mode = mode
    }
}
