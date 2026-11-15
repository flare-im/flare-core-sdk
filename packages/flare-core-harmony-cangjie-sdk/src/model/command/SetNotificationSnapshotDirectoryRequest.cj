package flare_core_harmony_cangjie_sdk.model.command

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Where the engine keeps the notification snapshot an iOS notification service extension reads.
public class SetNotificationSnapshotDirectoryRequest {
    // wire: `directory`. Optional. Directory shared with the extension (the App Group container on iOS). The engine writes snapshot.json there and reads the extension's receipts.log from it. Absent: stop writing; files already there are left alone.
    public let directory: ?String

    public init(directory!: ?String) {
        this.directory = directory
    }
}
