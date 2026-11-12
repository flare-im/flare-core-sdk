import Foundation

/// GENERATED. Do not edit by hand.
/// One notification to show (or to replace in place).
public struct NotificationPresentation: Codable, Sendable {
    /// wire: `body`. Body, already rendered in the app's language.
    public let body: String
    /// wire: `channel`. messages, quiet, mentions or urgent (Android channel flare.<channel>).
    public let channel: String
    /// wire: `collapseId`. Notification identity: one per conversation. Used as the iOS notification identifier and the Android notification tag, so a later notification for the same conversation replaces it.
    public let collapseId: String
    /// wire: `conversationId`. Conversation the notification belongs to; empty for the digest notification.
    public let conversationId: String
    /// wire: `count`. Unread messages the notification stands for, at least 1.
    public let count: UInt32
    /// wire: `messageId`. Server id of the newest message it stands for; empty for a catch-up without a loaded message and for the digest notification.
    public let messageId: String
    /// wire: `seq`. Conversation seq of the newest message it stands for; 0 for the digest notification.
    public let seq: UInt64
    /// wire: `sound`. Whether to play a sound; a silent replacement never sounds.
    public let sound: Bool
    /// wire: `surface`. system (an OS notification) or inApp (a banner inside the running app).
    public let surface: String
    /// wire: `threadId`. Grouping key in the notification centre.
    public let threadId: String
    /// wire: `title`. Title, already rendered in the app's language.
    public let title: String

    public init(body: String = "", channel: String = "", collapseId: String = "", conversationId: String = "", count: UInt32 = 0, messageId: String = "", seq: UInt64 = 0, sound: Bool = false, surface: String = "", threadId: String = "", title: String = "") {
        self.body = body
        self.channel = channel
        self.collapseId = collapseId
        self.conversationId = conversationId
        self.count = count
        self.messageId = messageId
        self.seq = seq
        self.sound = sound
        self.surface = surface
        self.threadId = threadId
        self.title = title
    }
}
