// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { LifecycleApi } from '../../api/modules/lifecycle';
import type { SetAppStateRequest } from '../../model';
import { invokeVoid } from '../codec/NativeInvoke';
import { setAppStateRequestToMap } from '../codec/WireCodec';

export class DefaultLifecycleApi implements LifecycleApi {
  constructor(private readonly bridge: NativeBridge) {}

  async setAppState(request: SetAppStateRequest): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.lifecycleSetAppState, setAppStateRequestToMap(request));
  }
}
