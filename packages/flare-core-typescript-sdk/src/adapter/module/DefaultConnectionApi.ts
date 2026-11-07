// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/bridge_contract';
import type { ConnectionApi } from '../../api/modules/connection';
import { ConnectionStatus, NetworkChangeRequest, ServerClockResponse } from '../../model';
import { invokeBool, invokeConversation, invokeConversationTimelineSnapshot, invokeHomeTimelineSnapshot, invokeList, invokeListConversations, invokeListMessages, invokeMap, invokeMessage, invokeSendAck, invokeVoid, sdkErrorPayloadFromError, withoutNullFields } from '../codec/nativeInvoke';
import { connectionStatusFromJson } from './DefaultEventsApi';
import { conversationFromJson, listConversationsResponseFromJson, listMessagesResponseFromJson, listOfMaps, messageFromJson, networkChangeRequestToMap, sendAckFromJson, sendMessageRequestToMap } from '../codec/wireCodec';

export class DefaultConnectionApi implements ConnectionApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getStatus(): Promise<ConnectionStatus> {
    return connectionStatusFromJson(await invokeMap(this.bridge, NativeCallMap.connectionGetStatus));
  }

  async reconnectNow(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionReconnectNow);
  }

  async disconnect(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionDisconnect);
  }

  async getServerClock(): Promise<ServerClockResponse> {
    return await invokeMap(this.bridge, NativeCallMap.connectionServerClock) as unknown as ServerClockResponse;
  }

  async notifyNetworkChange(request: NetworkChangeRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionNotifyNetworkChange, networkChangeRequestToMap(request));
  }
}
