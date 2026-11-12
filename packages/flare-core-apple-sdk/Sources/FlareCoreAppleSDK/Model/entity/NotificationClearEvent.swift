import Foundation

/// GENERATED. Do not edit by hand.
/// Payload of notification.clear: remove these notifications of the app.
public struct NotificationClearEvent: Codable, Sendable {
    /// wire: `all`. Remove every notification of the app (the session ended); collapseIds is then empty.
    public let all: Bool
    /// wire: `collapseIds`. Collapse ids of the notifications to remove.
    public let collapseIds: [String]

    public init(all: Bool = false, collapseIds: [String] = []) {
        self.all = all
        self.collapseIds = collapseIds
    }
}
