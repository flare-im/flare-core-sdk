import Foundation

/// GENERATED. Do not edit by hand.
/// A prompt really appeared.
public struct UpdateMarkPromptedRequest: Codable, Sendable {
    /// wire: `build`. Build the prompt is about; absent when a forced update has no release yet.
    public let build: UInt64?
    /// wire: `form`. sheet, modal or fullscreen.
    public let form: String

    public init(build: UInt64? = nil, form: String = "") {
        self.build = build
        self.form = form
    }
}
