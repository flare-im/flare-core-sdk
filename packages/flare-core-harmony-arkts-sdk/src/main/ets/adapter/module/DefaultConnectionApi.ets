// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { ConnectionApi } from '../../api/modules/connection';
import type { ConnectionStatus, NetworkChangeRequest, ServerClockResponse } from '../../model';
import { invokeMap, invokeVoid } from '../codec/NativeInvoke';
import { connectionStatusFromJson, networkChangeRequestToMap, serverClockResponseFromJson } from '../codec/WireCodec';

export class DefaultConnectionApi implements ConnectionApi {
  constructor(private readonly bridge: NativeBridge) {}

  async getStatus(): Promise<ConnectionStatus> {
    const raw = await invokeMap(this.bridge, NativeCallMap.connectionGetStatus);
    return connectionStatusFromJson(raw);
  }

  async reconnectNow(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionReconnectNow);
  }

  async disconnect(): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionDisconnect);
  }

  async getServerClock(): Promise<ServerClockResponse> {
    const raw = await invokeMap(this.bridge, NativeCallMap.connectionServerClock);
    return serverClockResponseFromJson(raw);
  }

  async notifyNetworkChange(request: NetworkChangeRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.connectionNotifyNetworkChange, networkChangeRequestToMap(request));
  }
}
