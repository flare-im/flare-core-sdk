// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallMap } from '../../contract/BridgeContract';
import type { UserApi } from '../../api/modules/user';
import { invokeVoid } from '../codec/NativeInvoke';

/** Business-fed user profiles for the core's identity cache (`user.upsert_profiles`). */
export class DefaultUserApi implements UserApi {
  constructor(private readonly bridge: NativeBridge) {}

  async upsertUserProfiles(request: Record<string, Object>): Promise<void> {
    await invokeVoid(this.bridge, NativeCallMap.userUpsertProfiles, request);
  }
}
