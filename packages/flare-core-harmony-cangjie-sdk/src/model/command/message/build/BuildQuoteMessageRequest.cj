package flare_core_harmony_cangjie_sdk.model.command.message.build

import flare_core_harmony_cangjie_sdk.model.entity.MessageContent

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Build a quote/reply message.
public class BuildQuoteMessageRequest {
    // wire: `conversationId`. Target conversation id.
    public let conversationId: String
    // wire: `quotedMessageId`. Quoted message id.
    public let quotedMessageId: String
    // wire: `text`. Reply text.
    public let text: String
    // wire: `quotedSenderId`. Optional. Quoted sender id.
    public let quotedSenderId: ?String
    // wire: `quotedTextPreview`. Optional. Quoted preview text.
    public let quotedTextPreview: ?String
    // wire: `quotedContent`. Quoted message content element.
    public let quotedContent: MessageContent

    public init(conversationId!: String, quotedMessageId!: String, text!: String, quotedSenderId!: ?String, quotedTextPreview!: ?String, quotedContent!: MessageContent) {
        this.conversationId = conversationId
        this.quotedMessageId = quotedMessageId
        this.text = text
        this.quotedSenderId = quotedSenderId
        this.quotedTextPreview = quotedTextPreview
        this.quotedContent = quotedContent
    }
}
