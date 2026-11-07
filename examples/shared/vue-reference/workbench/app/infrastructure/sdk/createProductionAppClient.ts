import type { FlareImClient, SdkConfig } from "@flare-im/sdk/api";
import type { FlareUpdateInstaller } from "@flare-im/sdk/update";
import type { SdkRuntimeStatus } from "../../../composables/useFlareCoreClient";

export type ProductionAppClientFactory = () => FlareImClient;
let clientFactory: ProductionAppClientFactory | null = null;

export function configureProductionAppClientFactory(factory: ProductionAppClientFactory | null): void {
  clientFactory = factory;
}

export function createProductionAppClient(): FlareImClient {
  if (!clientFactory) throw new Error("Configure the platform SDK client before mounting the reference app");
  return clientFactory();
}

/** What a platform host adds to the shared reference app besides its client. */
export interface ProductionAppHost {
  /**
   * The host's own SDK settings for every init, such as the private CA a native runtime trusts for TLS or the app
   * identity the platform cannot fill in. Never an endpoint: where to connect is the build's access configuration alone.
   */
  sdkConfig?: () => Pick<SdkConfig, "tlsCaCert" | "tlsCaCertPath" | "app">;
  /** Runtime label for diagnostics (default `browser-wasm`). */
  runtimeStatus?: SdkRuntimeStatus;
  /**
   * The platform's update installer. `isInputEmpty` says whether the composer holds nothing. Without an installer the
   * app has no update center: no prompt, and the connection notice offers no update action.
   */
  createUpdateInstaller?: (client: FlareImClient, isInputEmpty: () => boolean) => FlareUpdateInstaller;
  /** Opens the failure prompt's website or store address. */
  openUrl?: (url: string) => void | Promise<void>;
  /** Hands over every recovery link the system delivers; a browser has none. */
  followRecoveryLinks?: (onLink: (link: string) => void) => Promise<void>;
}

let host: ProductionAppHost = {};

export function configureProductionAppHost(next: ProductionAppHost): void {
  host = { ...next };
}

export function productionAppHost(): ProductionAppHost {
  return host;
}
