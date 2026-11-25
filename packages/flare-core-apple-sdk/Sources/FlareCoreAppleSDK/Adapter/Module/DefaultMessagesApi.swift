import Foundation

/// GENERATED. Do not edit by hand.
// Models: CreateTextMessageRequest, ListMessagesRequest, ListMessagesResponse, Message, MessageSearchQuery, SendMessageRequest, SendMessageResponse
public final class DefaultMessagesApi: MessagesApiProtocol {
    private let bridge: any NativeBridgeProtocol

    public init(bridge: any NativeBridgeProtocol) {
        self.bridge = bridge
    }

    public func createTextMessage(_ request: CreateTextMessageRequest) async throws -> Message {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageCreateText, request: unwrapRequest(AnySendable(createTextMessageRequestToMap(request))))
        return try messageFromJson(raw["message"] ?? raw)
    }

    public func dispatchMessage(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.messageDispatch, request: unwrapRequest(AnySendable(request)))
    }

    public func sendMessageNoOss(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageSendNoOss, request: messageToWireMap(request.message))
        return try sendAckFromJson(raw)
    }

    public func sendMessage(_ request: SendMessageRequest, callback: (any MessageSendCallback)?) async throws -> SendMessageResponse {
        let wireRequest = messageToWireMap(request.message)
        do {
            let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageSend, request: wireRequest)
            let ack = try sendAckFromJson(raw)
            callback?.onSuccess(MessageSendAckEvent(ack: ack))
            return ack
        } catch {
            let payload = sdkErrorPayload(from: error, operation: "message.send")
            callback?.onFailure(MessageSendFailedEvent(
                clientMsgId: request.message.clientMsgId,
                reason: payload.message,
                error: payload
            ))
            throw error
        }
    }

    public func listMessages(_ request: ListMessagesRequest) async throws -> ListMessagesResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageList, request: unwrapRequest(AnySendable(listMessagesRequestToMap(request))))
        return try listMessagesResponseFromJson(raw)
    }

    public func recallMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageRecall, request: AnySendable(request))
    }

    public func editTextByMessageId(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageEditTextByMessageId, request: AnySendable(request))
    }

    public func deleteMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageDelete, request: AnySendable(request))
    }

    public func deleteMessageForSelf(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageDeleteForSelf, request: AnySendable(request))
    }

    public func deleteMessageForEveryone(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageDeleteForEveryone, request: AnySendable(request))
    }


    public func markMessageReadAndBurn(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageMarkReadAndBurn, request: AnySendable(request))
    }

    public func addReaction(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageAddReaction, request: AnySendable(request))
    }

    public func removeReaction(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageRemoveReaction, request: AnySendable(request))
    }

    public func pinMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messagePin, request: AnySendable(request))
    }

    public func unpinMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageUnpin, request: AnySendable(request))
    }

    public func pinMessageById(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messagePinByMessageId, request: AnySendable(request))
    }

    public func unpinMessageById(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageUnpinByMessageId, request: AnySendable(request))
    }

    public func markMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageMark, request: AnySendable(request))
    }

    public func markMessageWithColor(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageMarkWithColor, request: AnySendable(request))
    }

    public func unmarkMessage(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageUnmark, request: AnySendable(request))
    }

    public func markMessageById(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageMarkByMessageId, request: AnySendable(request))
    }

    public func unmarkMessageById(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageUnmarkByMessageId, request: AnySendable(request))
    }

    public func getMessage(_ request: [String: AnySendable]) async throws -> Message {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageGet, request: unwrapRequest(AnySendable(request)))
        return try messageFromJson(raw["message"] ?? raw)
    }

    public func getMessageByKey(_ request: MessageKey) async throws -> MessageByKeyResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageGetByKey, request: messageKeyToMap(request))
        return try messageByKeyResponseFromJson(raw)
    }

    public func getRawMessage(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.messageGetRaw, request: unwrapRequest(AnySendable(request)))
    }

    public func awaitMessageConfirmation(_ request: [String: AnySendable]) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.messageAwaitConfirmation, request: unwrapRequest(AnySendable(request)))
    }

    public func searchMessages(_ request: MessageSearchQuery) async throws -> ListMessagesResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageSearch, request: unwrapRequest(AnySendable(messageSearchQueryToMap(request))))
        return try listMessagesResponseFromJson(raw)
    }

    public func searchMessagesByQuery(_ request: MessageSearchQuery) async throws -> ListMessagesResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageSearchByQuery, request: unwrapRequest(AnySendable(messageSearchQueryToMap(request))))
        return try listMessagesResponseFromJson(raw)
    }

    public func searchMessagesInConversation(_ request: MessageSearchQuery) async throws -> ListMessagesResponse {
        let raw = try await invokeMap(bridge, descriptor: NativeCallMap.messageSearchInConversation, request: unwrapRequest(AnySendable(messageSearchQueryToMap(request))))
        return try listMessagesResponseFromJson(raw)
    }

    public func readReceiptMembers(_ request: MessageReadReceiptMembersRequest) async throws -> [String: AnySendable] {
        return try await invokeMap(bridge, descriptor: NativeCallMap.messageReadReceiptMembers, request: messageReadReceiptMembersRequestToMap(request))
    }

    public func editRichDocByMessageId(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageEditRichDocByMessageId, request: AnySendable(request))
    }

    public func setTyping(_ request: [String: AnySendable]) async throws -> Void {
        try await invokeVoid(bridge, descriptor: NativeCallMap.messageTyping, request: AnySendable(request))
    }

}
