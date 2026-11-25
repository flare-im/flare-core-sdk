import Foundation

/// GENERATED. Do not edit by hand.
/// Message build, send, query and mutation.
public protocol MessagesApiProtocol: AnyObject {
    func createTextMessage(_ request: CreateTextMessageRequest) async throws -> Message
    func dispatchMessage(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func sendMessageNoOss(_ request: SendMessageRequest) async throws -> SendMessageResponse
    func sendMessage(_ request: SendMessageRequest, callback: (any MessageSendCallback)?) async throws -> SendMessageResponse
    func listMessages(_ request: ListMessagesRequest) async throws -> ListMessagesResponse
    func recallMessage(_ request: [String: AnySendable]) async throws -> Void
    func editTextByMessageId(_ request: [String: AnySendable]) async throws -> Void
    func deleteMessage(_ request: [String: AnySendable]) async throws -> Void
    func deleteMessageForSelf(_ request: [String: AnySendable]) async throws -> Void
    func deleteMessageForEveryone(_ request: [String: AnySendable]) async throws -> Void
    func markMessageReadAndBurn(_ request: [String: AnySendable]) async throws -> Void
    func addReaction(_ request: [String: AnySendable]) async throws -> Void
    func removeReaction(_ request: [String: AnySendable]) async throws -> Void
    func pinMessage(_ request: [String: AnySendable]) async throws -> Void
    func unpinMessage(_ request: [String: AnySendable]) async throws -> Void
    func pinMessageById(_ request: [String: AnySendable]) async throws -> Void
    func unpinMessageById(_ request: [String: AnySendable]) async throws -> Void
    func markMessage(_ request: [String: AnySendable]) async throws -> Void
    func markMessageWithColor(_ request: [String: AnySendable]) async throws -> Void
    func unmarkMessage(_ request: [String: AnySendable]) async throws -> Void
    func markMessageById(_ request: [String: AnySendable]) async throws -> Void
    func unmarkMessageById(_ request: [String: AnySendable]) async throws -> Void
    func getMessage(_ request: [String: AnySendable]) async throws -> Message
    func getMessageByKey(_ request: MessageKey) async throws -> MessageByKeyResponse
    func awaitMessageConfirmation(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func getRawMessage(_ request: [String: AnySendable]) async throws -> [String: AnySendable]
    func searchMessages(_ request: MessageSearchQuery) async throws -> ListMessagesResponse
    func searchMessagesByQuery(_ request: MessageSearchQuery) async throws -> ListMessagesResponse
    func searchMessagesInConversation(_ request: MessageSearchQuery) async throws -> ListMessagesResponse
    func readReceiptMembers(_ request: MessageReadReceiptMembersRequest) async throws -> [String: AnySendable]
    func editRichDocByMessageId(_ request: [String: AnySendable]) async throws -> Void
    func setTyping(_ request: [String: AnySendable]) async throws -> Void
}
