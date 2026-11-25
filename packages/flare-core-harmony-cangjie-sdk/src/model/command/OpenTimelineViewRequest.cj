package flare_core_harmony_cangjie_sdk.model.command

import flare_core_harmony_cangjie_sdk.model.entity.TimelineAnchor

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Request for opening an observable conversation timeline view.
public class OpenTimelineViewRequest {
    // wire: `conversationId`. Conversation id to observe.
    public let conversationId: String
    // wire: `messageLimit`. Page size: rows in the initial window and in each older or newer page when a paging request does not give its own (core default 40, at most 100).
    public let messageLimit: UInt32
    // wire: `anchor`. Optional. Open around this message instead of at the latest messages; the window holds half a page on each side of it.
    public let anchor: ?TimelineAnchor

    public init(conversationId!: String, messageLimit!: UInt32, anchor!: ?TimelineAnchor) {
        this.conversationId = conversationId
        this.messageLimit = messageLimit
        this.anchor = anchor
    }
}
