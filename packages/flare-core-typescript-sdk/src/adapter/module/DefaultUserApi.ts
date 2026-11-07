// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { UserApi } from '../../api/modules/user';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultUserApi implements UserApi {
  constructor(private readonly bridge: NativeBridge) {}

  async upsertUserProfiles(request: Record<string, unknown>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.userUpsertProfiles, request);
  }
}
