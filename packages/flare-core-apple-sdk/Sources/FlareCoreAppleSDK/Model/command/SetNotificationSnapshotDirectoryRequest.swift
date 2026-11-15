import Foundation

/// GENERATED. Do not edit by hand.
/// Where the engine keeps the notification snapshot an iOS notification service extension reads.
public struct SetNotificationSnapshotDirectoryRequest: Codable, Sendable {
    /// wire: `directory`. Directory shared with the extension (the App Group container on iOS). The engine writes snapshot.json there and reads the extension's receipts.log from it. Absent: stop writing; files already there are left alone.
    public let directory: String?

    public init(directory: String? = nil) {
        self.directory = directory
    }
}
