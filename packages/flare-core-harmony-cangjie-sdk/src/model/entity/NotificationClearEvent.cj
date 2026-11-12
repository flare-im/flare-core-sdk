package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Payload of notification.clear: remove these notifications of the app.
public class NotificationClearEvent {
    // wire: `all`. Remove every notification of the app (the session ended); collapseIds is then empty.
    public let all: Bool
    // wire: `collapseIds`. Collapse ids of the notifications to remove.
    public let collapseIds: String

    public init(all!: Bool, collapseIds!: String) {
        this.all = all
        this.collapseIds = collapseIds
    }
}
