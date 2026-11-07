// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { MessagesApi } from '../../api/modules/messages';
import type { MessageSendCallback } from '../../listener';
import { CreateTextMessageRequest, ListMessagesRequest, ListMessagesResponse, Message, MessageReadReceiptMembersRequest, MessageSearchQuery, SendMessageRequest, SendMessageResponse } from '../../model';
import { invokeBool, invokeConversation, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError } from '../codec/NativeInvoke';
import { conversationFromJson, createTextMessageRequestToMap, listConversationsResponseFromJson, listMessagesRequestToMap, listMessagesResponseFromJson, listOfMaps, messageFromJson, messageReadReceiptMembersRequestToMap, messageSearchQueryToMap, sendAckFromJson, sendMessageRequestToMap } from '../codec/WireCodec';

export class DefaultMessagesApi implements MessagesApi {
  constructor(private readonly bridge: NativeBridge) {}

  async createTextMessage(request: CreateTextMessageRequest): Promise<Message> {
    return await invokeMessage(this.bridge, NativeCallMap.messageCreateText, createTextMessageRequestToMap(request));
  }

  async dispatchMessage(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.messageDispatch, request);
  }

  async sendMessageNoOss(request: SendMessageRequest): Promise<SendMessageResponse> {
    return await invokeSendAck(this.bridge, NativeCallMap.messageSendNoOss, sendMessageRequestToMap(request));
  }

  async sendMessage(request: SendMessageRequest, callback?: MessageSendCallback): Promise<SendMessageResponse> {
    const wireRequest = sendMessageRequestToMap(request);
    try {
      const ack = await invokeSendAck(this.bridge, NativeCallMap.messageSend, wireRequest);
      callback?.onSuccess?.({ ack });
      return ack;
    } catch (error) {
      const payload = sdkErrorPayloadFromError(error as Object, "message.send");
      callback?.onFailure?.({
        clientMsgId: request.message.clientMsgId,
        reason: payload.message,
        error: payload,
      });
      throw error;
    }
  }

  async listMessages(request: ListMessagesRequest): Promise<ListMessagesResponse> {
    return await invokeListMessages(this.bridge, NativeCallMap.messageList, listMessagesRequestToMap(request));
  }

  async recallMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageRecall, request);
  }

  async editTextByMessageId(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageEditTextByMessageId, request);
  }

  async deleteMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDelete, request);
  }

  async deleteMessageForSelf(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDeleteForSelf, request);
  }

  async deleteMessageForEveryone(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDeleteForEveryone, request);
  }


  async markMessageReadAndBurn(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkReadAndBurn, request);
  }

  async addReaction(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageAddReaction, request);
  }

  async removeReaction(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageRemoveReaction, request);
  }

  async pinMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messagePin, request);
  }

  async unpinMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnpin, request);
  }

  async pinMessageById(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messagePinByMessageId, request);
  }

  async unpinMessageById(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnpinByMessageId, request);
  }

  async markMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMark, request);
  }

  async markMessageWithColor(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkWithColor, request);
  }

  async unmarkMessage(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnmark, request);
  }

  async markMessageById(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkByMessageId, request);
  }

  async unmarkMessageById(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnmarkByMessageId, request);
  }

  async getMessage(request: Record<string, Object>): Promise<Message> {
    return await invokeMessage(this.bridge, NativeCallMap.messageGet, request);
  }

  async getRawMessage(request: Record<string, Object>): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.messageGetRaw, request);
  }

  async searchMessages(request: MessageSearchQuery): Promise<ListMessagesResponse> {
    return await invokeListMessages(this.bridge, NativeCallMap.messageSearch, messageSearchQueryToMap(request));
  }

  async searchMessagesByQuery(request: MessageSearchQuery): Promise<ListMessagesResponse> {
    return await invokeListMessages(this.bridge, NativeCallMap.messageSearchByQuery, messageSearchQueryToMap(request));
  }

  async searchMessagesInConversation(request: MessageSearchQuery): Promise<ListMessagesResponse> {
    return await invokeListMessages(this.bridge, NativeCallMap.messageSearchInConversation, messageSearchQueryToMap(request));
  }

  async readReceiptMembers(request: MessageReadReceiptMembersRequest): Promise<Record<string, Object>> {
    return await invokeMap(this.bridge, NativeCallMap.messageReadReceiptMembers, messageReadReceiptMembersRequestToMap(request));
  }

  async editRichDocByMessageId(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageEditRichDocByMessageId, request);
  }

  async setTyping(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageTyping, request);
  }
}
