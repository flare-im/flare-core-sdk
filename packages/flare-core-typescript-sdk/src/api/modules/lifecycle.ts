/**
 * GENERATED. Do not edit by hand.
 *
 * Module API: `lifecycle` — Platform lifecycle signals the core needs (foreground and background).
 */
import type { SetAppStateRequest } from '../../model';

/** Platform lifecycle signals the core needs (foreground and background). */
export interface LifecycleApi {
  /** setAppState maps to `flare_sdk_invoke_json`. Operation: `lifecycle.set_app_state`. */
  setAppState(request: SetAppStateRequest): Promise<void>;
}
