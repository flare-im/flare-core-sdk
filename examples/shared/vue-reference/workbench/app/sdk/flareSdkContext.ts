import { inject, provide, type InjectionKey } from "vue";
import { currentFlareRuntimeLocale } from "@flare-im/vue-ui/i18n";
import { useFlareCoreClient } from "../../composables/sdk";
import { createProductionAppClient, productionAppHost } from "../infrastructure/sdk/createProductionAppClient";
import { buildAccessConfig } from "../runtime/access";

export type FlareSdkContext = ReturnType<typeof useFlareCoreClient>;

export const flareSdkKey: InjectionKey<FlareSdkContext> = Symbol("flare-sdk");

let flareSdkSingleton: FlareSdkContext | null = null;

export function getFlareSdkSingleton(): FlareSdkContext | null {
  return flareSdkSingleton;
}

export function provideFlareSdk(): FlareSdkContext {
  const host = productionAppHost();
  const sdk = useFlareCoreClient({
    createClient: createProductionAppClient,
    env: import.meta.env as Record<string, string | undefined>,
    // Where to connect is the build's access configuration; the host only adds its own settings (a private CA). Every
    // init gets the whole `app`: the core replaces it, and release notes follow the language of the moment.
    sdkConfig: () => {
      const own = host.sdkConfig?.();
      return { ...own, access: buildAccessConfig(), app: { ...own?.app, locale: currentFlareRuntimeLocale() } };
    },
    runtimeStatus: host.runtimeStatus ?? "browser-wasm",
  });
  flareSdkSingleton = sdk;
  provide(flareSdkKey, sdk);
  return sdk;
}

export function useFlareSdk(): FlareSdkContext {
  const sdk = inject(flareSdkKey);
  if (!sdk) {
    throw new Error("Flare SDK context is missing. Mount provideFlareSdk() in App.vue.");
  }
  return sdk;
}
