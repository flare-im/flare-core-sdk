package flare_core_harmony_cangjie_sdk.api.modules

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Message build, send, query and mutation.
public interface MessagesApi {
    func createTextMessage(request: CreateTextMessageRequest): Message
    func dispatchMessage(requestJson: String): JsonValue
    func sendMessageNoOss(request: SendMessageRequest): SendMessageResponse
    func sendMessage(request: SendMessageRequest): SendMessageResponse
    func listMessages(request: ListMessagesRequest): ListMessagesResponse
    func recallMessage(requestJson: String): Unit
    func editTextByMessageId(requestJson: String): Unit
    func deleteMessage(requestJson: String): Unit
    func deleteMessageForSelf(requestJson: String): Unit
    func deleteMessageForEveryone(requestJson: String): Unit
    func markMessageReadAndBurn(requestJson: String): Unit
    func addReaction(requestJson: String): Unit
    func removeReaction(requestJson: String): Unit
    func pinMessage(requestJson: String): Unit
    func unpinMessage(requestJson: String): Unit
    func pinMessageById(requestJson: String): Unit
    func unpinMessageById(requestJson: String): Unit
    func markMessage(requestJson: String): Unit
    func markMessageWithColor(requestJson: String): Unit
    func unmarkMessage(requestJson: String): Unit
    func markMessageById(requestJson: String): Unit
    func unmarkMessageById(requestJson: String): Unit
    func getMessage(requestJson: String): Message
    func getMessageByKey(request: MessageKey): MessageByKeyResponse
    func awaitMessageConfirmation(requestJson: String): JsonValue
    func getRawMessage(requestJson: String): JsonValue
    func searchMessages(request: MessageSearchQuery): ListMessagesResponse
    func searchMessagesByQuery(request: MessageSearchQuery): ListMessagesResponse
    func searchMessagesInConversation(request: MessageSearchQuery): ListMessagesResponse
    func readReceiptMembers(request: MessageReadReceiptMembersRequest): String
    func editRichDocByMessageId(requestJson: String): Unit
    func setTyping(requestJson: String): Unit
}
