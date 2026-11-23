package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Typed delta emitted by core observable views. A timeline delta works by the message timelineKey (canonical server identity for confirmed rows; ACK migrates the local row identity): remove the keys in remove, replace the rows in upsert in place, put prepend first and append last, reorder by every key when reorder is present, then take the three state fields and conversation. A conversation-list delta is the indexed ops list.
public class ViewDelta {
    // wire: `viewType`. Delta tag: timeline or conversationList.
    public let viewType: String
    // wire: `prepend`. Optional. Timeline: older rows to put before the first row, in timeline order.
    public let prepend: ?String
    // wire: `append`. Optional. Timeline: newer rows to put after the last row, in timeline order.
    public let append: ?String
    // wire: `upsert`. Optional. Timeline: new content of rows already in the window, replaced in place by row key.
    public let upsert: ?String
    // wire: `remove`. Optional. Timeline: row keys leaving the window.
    public let remove: ?String
    // wire: `reorder`. Optional. Timeline: every row key in the new order; only when the order changed in a way the other steps cannot express.
    public let reorder: ?String
    // wire: `hasOlder`. Optional. Timeline: whether more visible messages exist below the window.
    public let hasOlder: ?Bool
    // wire: `hasNewer`. Optional. Timeline: whether more messages exist above the window.
    public let hasNewer: ?Bool
    // wire: `attachedToLatest`. Optional. Timeline: whether the window is attached to the latest.
    public let attachedToLatest: ?Bool
    // wire: `conversation`. Optional. Timeline: the conversation header, only when it changed.
    public let conversation: ?Conversation
    // wire: `ops`. Optional. Conversation list: ordered indexed operations.
    public let ops: ?String
    // wire: `totalUnread`. Optional. Conversation list: latest total unread value.
    public let totalUnread: ?UInt64
    // wire: `syncState`. Optional. Conversation list: latest sync state.
    public let syncState: ?String

    public init(viewType!: String, prepend!: ?String, append!: ?String, upsert!: ?String, remove!: ?String, reorder!: ?String, hasOlder!: ?Bool, hasNewer!: ?Bool, attachedToLatest!: ?Bool, conversation!: ?Conversation, ops!: ?String, totalUnread!: ?UInt64, syncState!: ?String) {
        this.viewType = viewType
        this.prepend = prepend
        this.append = append
        this.upsert = upsert
        this.remove = remove
        this.reorder = reorder
        this.hasOlder = hasOlder
        this.hasNewer = hasNewer
        this.attachedToLatest = attachedToLatest
        this.conversation = conversation
        this.ops = ops
        this.totalUnread = totalUnread
        this.syncState = syncState
    }
}
