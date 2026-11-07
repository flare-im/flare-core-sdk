import Foundation

/// GENERATED. Do not edit by hand.
/// Imports a recovery link.
public struct AccessImportRecoveryRequest: Codable, Sendable {
    /// wire: `link`. The flare-recover:// deep link or QR code content, verbatim.
    public let link: String

    public init(link: String = "") {
        self.link = link
    }
}
