import Foundation

/// GENERATED. Do not edit by hand.
/// Typed delta emitted by core observable views. A timeline delta works by the message timelineKey (canonical server identity for confirmed rows; ACK migrates the local row identity): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list.
public struct ViewDelta: Sendable {
    /// wire: `viewType`. Delta tag: timeline or conversationList.
    public let viewType: String
    /// wire: `prepend`. Timeline: older rows to put before the first row, in timeline order.
    public let prepend: [Message]?
    /// wire: `append`. Timeline: newer rows to put after the last row, in timeline order.
    public let append: [Message]?
    /// wire: `upsert`. Timeline: new content of rows already in the window, replaced in place by row key.
    public let upsert: [Message]?
    /// wire: `remove`. Timeline: row keys leaving the window.
    public let remove: [String]?
    /// wire: `reorder`. Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express.
    public let reorder: [String]?
    /// wire: `hasOlder`. Timeline: whether more visible messages exist below the window.
    public let hasOlder: Bool?
    /// wire: `hasNewer`. Timeline: whether more messages exist above the window.
    public let hasNewer: Bool?
    /// wire: `attachedToLatest`. Timeline: whether the window is attached to the latest.
    public let attachedToLatest: Bool?
    /// wire: `conversation`. Timeline: the conversation header, only when it changed.
    public let conversation: Conversation?
    /// wire: `ops`. Conversation list: ordered indexed operations.
    public let ops: [ViewDeltaOp]?
    /// wire: `totalUnread`. Conversation list: latest total unread value.
    public let totalUnread: UInt64?
    /// wire: `syncState`. Conversation list: latest sync state.
    public let syncState: String?

    public init(viewType: String = "", prepend: [Message]? = nil, append: [Message]? = nil, upsert: [Message]? = nil, remove: [String]? = nil, reorder: [String]? = nil, hasOlder: Bool? = nil, hasNewer: Bool? = nil, attachedToLatest: Bool? = nil, conversation: Conversation? = nil, ops: [ViewDeltaOp]? = nil, totalUnread: UInt64? = nil, syncState: String? = nil) {
        self.viewType = viewType
        self.prepend = prepend
        self.append = append
        self.upsert = upsert
        self.remove = remove
        self.reorder = reorder
        self.hasOlder = hasOlder
        self.hasNewer = hasNewer
        self.attachedToLatest = attachedToLatest
        self.conversation = conversation
        self.ops = ops
        self.totalUnread = totalUnread
        self.syncState = syncState
    }
}
