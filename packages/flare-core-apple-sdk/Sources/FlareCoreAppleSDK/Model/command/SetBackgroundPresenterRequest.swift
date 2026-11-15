import Foundation

/// GENERATED. Do not edit by hand.
/// Whether the platform presents alerts itself while the app is in the background.
public struct SetBackgroundPresenterRequest: Codable, Sendable {
    /// wire: `attached`. The platform push module posts local notifications for the engine while the app is in the background.
    public let attached: Bool

    public init(attached: Bool = false) {
        self.attached = attached
    }
}
