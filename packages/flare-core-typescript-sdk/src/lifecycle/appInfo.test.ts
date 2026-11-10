import { afterEach, describe, expect, it, vi } from "vitest";

import { webAppInfoFromBuild, withWebAppInfo } from "./appInfo";

describe("distribution in the app identity", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("reads the build-time distribution", () => {
    vi.stubGlobal("__FLARE_APP_DISTRIBUTION__", " electron ");

    expect(webAppInfoFromBuild().distribution).toBe("electron");
  });

  it("leaves distribution out when the build set none", () => {
    expect(webAppInfoFromBuild().distribution).toBeUndefined();
  });

  it("fills the init request's distribution unless the host gave one", () => {
    const filled = withWebAppInfo({ sdkConfig: {} }, { distribution: "electron" }) as {
      sdkConfig: { app: { distribution: string } };
    };
    expect(filled.sdkConfig.app.distribution).toBe("electron");

    const given = withWebAppInfo({ sdkConfig: { app: { distribution: "direct" } } }, { distribution: "electron" }) as {
      sdkConfig: { app: { distribution: string } };
    };
    expect(given.sdkConfig.app.distribution).toBe("direct");
  });
});
