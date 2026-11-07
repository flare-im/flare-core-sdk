import Foundation

/// GENERATED. Do not edit by hand.
/// Chooses the language of the release notes and blockReason.
public struct UpdateSetLocaleRequest: Codable, Sendable {
    /// wire: `locale`. BCP 47 tag, for example zh-Hant-TW.
    public let locale: String

    public init(locale: String = "") {
        self.locale = locale
    }
}
