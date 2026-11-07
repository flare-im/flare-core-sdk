import {
  configureAppPlatform,
  configureProductionAppClientFactory,
  configureProductionAppHost,
  sdkMediaProxyFields,
} from "./workbench/app";
import { configureMediaProxy } from "@flare-im/vue-ui/utils";
import { applyFlareColorScheme } from "@flare-im/vue-ui/theme";
import {
  flareMessages,
  registerFlareMessages,
  type FlareMessageTree,
} from "@flare-im/vue-ui/i18n";
import type { ReferenceRuntime } from "./runtime";
import { flareMessages as legacyWorkbenchMessages } from "./workbench/i18n/legacyMessages";
import "./workbench/app/styles/index.css";

function missingMessages(current: FlareMessageTree | undefined, source: FlareMessageTree): FlareMessageTree {
  const patch: FlareMessageTree = {};
  for (const [key, value] of Object.entries(source)) {
    const existing = current?.[key];
    if (typeof value === "string") {
      if (typeof existing !== "string") patch[key] = value;
      continue;
    }
    if (!existing || typeof existing === "string") {
      patch[key] = value;
      continue;
    }
    const nested = missingMessages(existing, value);
    if (Object.keys(nested).length) patch[key] = nested;
  }
  return patch;
}

export function configureReferenceApp(runtime: ReferenceRuntime): void {
  for (const [locale, messages] of Object.entries(legacyWorkbenchMessages)) {
    registerFlareMessages(locale, missingMessages(flareMessages[locale], messages));
  }
  configureProductionAppClientFactory(runtime.createClient);
  configureProductionAppHost({
    sdkConfig: runtime.sdkConfig,
    runtimeStatus: runtime.runtimeStatus,
    createUpdateInstaller: runtime.createUpdateInstaller,
    openUrl: runtime.openUrl,
    followRecoveryLinks: runtime.followRecoveryLinks,
  });
  configureAppPlatform(runtime.platform);
  configureMediaProxy(sdkMediaProxyFields());
  applyFlareColorScheme("violet", false);
}
