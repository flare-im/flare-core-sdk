package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// One notification to show (or to replace in place).
public class NotificationPresentation {
    // wire: `body`. Body, already rendered in the app's language.
    public let body: String
    // wire: `channel`. messages, quiet, mentions or urgent (Android channel flare.<channel>).
    public let channel: String
    // wire: `collapseId`. Notification identity: one per conversation. Used as the iOS notification identifier and the Android notification tag, so a later notification for the same conversation replaces it.
    public let collapseId: String
    // wire: `conversationId`. Conversation the notification belongs to; empty for the digest notification.
    public let conversationId: String
    // wire: `count`. Unread messages the notification stands for, at least 1.
    public let count: UInt32
    // wire: `messageId`. Server id of the newest message it stands for; empty for a catch-up without a loaded message and for the digest notification.
    public let messageId: String
    // wire: `seq`. Conversation seq of the newest message it stands for; 0 for the digest notification.
    public let seq: UInt64
    // wire: `sound`. Whether to play a sound; a silent replacement never sounds.
    public let sound: Bool
    // wire: `surface`. system (an OS notification) or inApp (a banner inside the running app).
    public let surface: String
    // wire: `threadId`. Grouping key in the notification centre.
    public let threadId: String
    // wire: `title`. Title, already rendered in the app's language.
    public let title: String

    public init(body!: String, channel!: String, collapseId!: String, conversationId!: String, count!: UInt32, messageId!: String, seq!: UInt64, sound!: Bool, surface!: String, threadId!: String, title!: String) {
        this.body = body
        this.channel = channel
        this.collapseId = collapseId
        this.conversationId = conversationId
        this.count = count
        this.messageId = messageId
        this.seq = seq
        this.sound = sound
        this.surface = surface
        this.threadId = threadId
        this.title = title
    }
}
