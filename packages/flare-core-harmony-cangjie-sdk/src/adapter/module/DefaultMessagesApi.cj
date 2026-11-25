package flare_core_harmony_cangjie_sdk.adapter

import flare_core_harmony_cangjie_sdk.contract.*
import flare_core_harmony_cangjie_sdk.api.modules.*
import flare_core_harmony_cangjie_sdk.listener.*
import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.

public class DefaultMessagesApi <: MessagesApi {
    private let bridge: NativeBridge

    public init(bridge: NativeBridge) {
        this.bridge = bridge
    }

    public func createTextMessage(request: CreateTextMessageRequest): Message {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageCreateText, requestJson: wireEncodeRequest(createTextMessageRequestToJson(request)))
        return messageFromEnvelopeJson(raw)
    }

    public func dispatchMessage(requestJson: String): JsonValue {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageDispatch, requestJson: wireEncodeRequest(requestJson))
        return JsonValue(raw)
    }

    public func sendMessageNoOss(request: SendMessageRequest): SendMessageResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageSendNoOss, requestJson: wireEncodeRequest(sendMessageRequestToJson(request)))
        return sendMessageResponseFromJson(raw)
    }

    public func sendMessage(request: SendMessageRequest): SendMessageResponse {
        return sendMessage(request, None)
    }

    public func sendMessage(request: SendMessageRequest, callback: ?MessageSendCallback): SendMessageResponse {
        let wire = sendMessageRequestToJson(request)
        let raw = bridge.invoke(descriptor: NativeCallMap.messageSend, requestJson: wire)
        let ack = sendMessageResponseFromJson(raw)
        match (callback) {
            case Some(cb) => cb.onSuccess(MessageSendAckEvent(ack: ack))
            case None => ()
        }
        return ack
    }

    public func listMessages(request: ListMessagesRequest): ListMessagesResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageList, requestJson: wireEncodeRequest(listMessagesRequestToJson(request)))
        return listMessagesResponseFromJson(raw)
    }

    public func recallMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageRecall, requestJson: wireEncodeRequest(requestJson))
    }

    public func editTextByMessageId(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageEditTextByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageDelete, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteMessageForSelf(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageDeleteForSelf, requestJson: wireEncodeRequest(requestJson))
    }

    public func deleteMessageForEveryone(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageDeleteForEveryone, requestJson: wireEncodeRequest(requestJson))
    }


    public func markMessageReadAndBurn(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageMarkReadAndBurn, requestJson: wireEncodeRequest(requestJson))
    }

    public func addReaction(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageAddReaction, requestJson: wireEncodeRequest(requestJson))
    }

    public func removeReaction(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageRemoveReaction, requestJson: wireEncodeRequest(requestJson))
    }

    public func pinMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messagePin, requestJson: wireEncodeRequest(requestJson))
    }

    public func unpinMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageUnpin, requestJson: wireEncodeRequest(requestJson))
    }

    public func pinMessageById(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messagePinByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func unpinMessageById(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageUnpinByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func markMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageMark, requestJson: wireEncodeRequest(requestJson))
    }

    public func markMessageWithColor(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageMarkWithColor, requestJson: wireEncodeRequest(requestJson))
    }

    public func unmarkMessage(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageUnmark, requestJson: wireEncodeRequest(requestJson))
    }

    public func markMessageById(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageMarkByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func unmarkMessageById(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageUnmarkByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func getMessage(requestJson: String): Message {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageGet, requestJson: wireEncodeRequest(requestJson))
        return messageFromEnvelopeJson(raw)
    }

    public func getMessageByKey(request: MessageKey): MessageByKeyResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageGetByKey, requestJson: wireEncodeRequest(messageKeyToJson(request)))
        return messageByKeyResponseFromJson(raw)
    }

    public func getRawMessage(requestJson: String): JsonValue {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageGetRaw, requestJson: wireEncodeRequest(requestJson))
        return JsonValue(raw)
    }

    public func searchMessages(request: MessageSearchQuery): ListMessagesResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageSearch, requestJson: wireEncodeRequest(messageSearchQueryToJson(request)))
        return listMessagesResponseFromJson(raw)
    }

    public func searchMessagesByQuery(request: MessageSearchQuery): ListMessagesResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageSearchByQuery, requestJson: wireEncodeRequest(messageSearchQueryToJson(request)))
        return listMessagesResponseFromJson(raw)
    }

    public func searchMessagesInConversation(request: MessageSearchQuery): ListMessagesResponse {
        let raw = bridge.invoke(descriptor: NativeCallMap.messageSearchInConversation, requestJson: wireEncodeRequest(messageSearchQueryToJson(request)))
        return listMessagesResponseFromJson(raw)
    }

    public func readReceiptMembers(request: MessageReadReceiptMembersRequest): String {
        return bridge.invoke(descriptor: NativeCallMap.messageReadReceiptMembers, requestJson: wireEncodeRequest(messageReadReceiptMembersRequestToJson(request)))
    }

    public func editRichDocByMessageId(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageEditRichDocByMessageId, requestJson: wireEncodeRequest(requestJson))
    }

    public func setTyping(requestJson: String): Unit {
        let _ignored = bridge.invoke(descriptor: NativeCallMap.messageTyping, requestJson: wireEncodeRequest(requestJson))
    }

}
