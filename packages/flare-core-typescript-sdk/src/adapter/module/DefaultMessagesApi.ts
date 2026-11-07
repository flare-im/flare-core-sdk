// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { MessagesApi } from '../../api/modules/messages';
import type { MessageSendCallback } from '../../callback';
import type { DeleteMessageRequest, EditRichDocByMessageIdRequest, EditTextByMessageIdRequest, GetMessageRequest, MarkMessageReadAndBurnRequest, MessageDispatchRequest, MessageMutationRequest, ReactionMutationRequest, RecallMessageRequest, SetTypingRequest } from '../../api/types';
import { CreateTextMessageRequest, ListMessagesRequest, ListMessagesResponse, Message, MessageReadReceiptMembersRequest, MessageSearchQuery, SendMessageRequest, SendMessageResponse } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, createTextMessageRequestToMap, listConversationsResponseFromJson, listMessagesRequestToMap, listMessagesResponseFromJson, listOfMaps, messageFromJson, messageReadReceiptMembersRequestToMap, messageSearchQueryToMap, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultMessagesApi implements MessagesApi {
  constructor(private readonly bridge: NativeBridge) {}

  async createTextMessage(request: CreateTextMessageRequest): Promise<Message> {
    return await invokeMessage(this.bridge, NativeCallMap.messageCreateText, createTextMessageRequestToMap(request));
  }

  async dispatchMessage(request: MessageDispatchRequest): Promise<unknown> {
    return await this.bridge.invoke<unknown>(NativeCallMap.messageDispatch, request);
  }

  async sendMessageNoOss(request: SendMessageRequest): Promise<SendMessageResponse> {
    return await invokeSendAck(this.bridge, NativeCallMap.messageSendNoOss, sendMessageRequestToMap(request));
  }

  async sendMessage(request: SendMessageRequest, callback?: MessageSendCallback): Promise<SendMessageResponse> {
    const wireRequest = sendMessageRequestToMap(request);
    try {
      const ack = await invokeSendAck(this.bridge, NativeCallMap.messageSend, wireRequest);
      if (ack.success === false) {
        callback?.onFailure?.({
          clientMsgId: request.message.clientMsgId,
          reason: ack.errorMessage,
          error: {
            code: String(ack.errorCode || 'send_ack_failed'),
            message: ack.errorMessage,
            operation: 'message.send',
            details: {
              ackId: ack.ackId,
              clientMsgId: ack.clientMsgId,
              conversationId: ack.conversationId,
              errorCode: String(ack.errorCode),
              errorMessage: ack.errorMessage,
              seq: String(ack.seq),
              serverId: ack.serverId,
              success: String(ack.success),
              timestamp: String(ack.timestamp),
            },
          },
        });
        return ack;
      }
      callback?.onSuccess?.({ ack });
      return ack;
    } catch (error) {
      const payload = sdkErrorPayloadFromError(error as unknown, "message.send");
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

  async recallMessage(request: RecallMessageRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageRecall, request);
  }

  async editTextByMessageId(request: EditTextByMessageIdRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageEditTextByMessageId, request);
  }

  async deleteMessage(request: DeleteMessageRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDelete, request);
  }

  async deleteMessageForSelf(request: DeleteMessageRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDeleteForSelf, request);
  }

  async deleteMessageForEveryone(request: DeleteMessageRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageDeleteForEveryone, request);
  }

  async markMessageReadAndBurn(request: MarkMessageReadAndBurnRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkReadAndBurn, request);
  }

  async addReaction(request: ReactionMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageAddReaction, request);
  }

  async removeReaction(request: ReactionMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageRemoveReaction, request);
  }

  async pinMessage(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messagePin, request);
  }

  async unpinMessage(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnpin, request);
  }

  async pinMessageById(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messagePinByMessageId, request);
  }

  async unpinMessageById(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnpinByMessageId, request);
  }

  async markMessage(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMark, request);
  }

  async markMessageWithColor(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkWithColor, request);
  }

  async unmarkMessage(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnmark, request);
  }

  async markMessageById(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageMarkByMessageId, request);
  }

  async unmarkMessageById(request: MessageMutationRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageUnmarkByMessageId, request);
  }

  async getMessage(request: GetMessageRequest): Promise<Message> {
    return await invokeMessage(this.bridge, NativeCallMap.messageGet, request);
  }

  async getRawMessage(request: GetMessageRequest): Promise<unknown> {
    return await this.bridge.invoke<unknown>(NativeCallMap.messageGetRaw, request);
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

  async readReceiptMembers(request: MessageReadReceiptMembersRequest): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.messageReadReceiptMembers, messageReadReceiptMembersRequestToMap(request));
  }

  async editRichDocByMessageId(request: EditRichDocByMessageIdRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageEditRichDocByMessageId, request);
  }

  async setTyping(request: SetTypingRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.messageTyping, request);
  }
}
