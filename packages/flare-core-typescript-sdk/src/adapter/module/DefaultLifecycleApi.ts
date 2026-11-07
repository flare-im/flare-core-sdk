// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { LifecycleApi } from '../../api/modules/lifecycle';
import { SetAppStateRequest } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap, setAppStateRequestToMap } from '../codec/wireCodec';

export class DefaultLifecycleApi implements LifecycleApi {
  constructor(private readonly bridge: NativeBridge) {}

  async setAppState(request: SetAppStateRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.lifecycleSetAppState, setAppStateRequestToMap(request));
  }
}
