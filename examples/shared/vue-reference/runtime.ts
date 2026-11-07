import type { FlareImClient } from "@flare-im/sdk/api";
import type { FlarePlatformOptions } from "@flare-im/vue-ui/composables";
import type { ProductionAppHost } from "./workbench/app/infrastructure/sdk/createProductionAppClient";

/** Platform factories supply public SDK clients; reference composition is shared. */
export interface ReferenceRuntime extends ProductionAppHost {
  id: "web" | "tauri";
  label: string;
  createClient: () => FlareImClient;
  /** The host's platform contract (kind / adapter / capability overrides) handed to FlareUiProvider. */
  platform?: FlarePlatformOptions;
}
