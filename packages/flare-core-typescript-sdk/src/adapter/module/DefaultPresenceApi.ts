// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { PresenceApi } from '../../api/modules/presence';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultPresenceApi implements PresenceApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getUserPresence(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.presenceGet, request);
  }

  async batchGetUserPresence(request: Record<string, unknown>): Promise<Record<string, unknown>> {
    return await invokeMap(this.bridge, NativeCallMap.presenceBatchGet, request);
  }

  async subscribeUserPresence(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.presenceSubscribe, request);
  }
}
