import { describe, expect, it } from "vitest";

// @ts-expect-error The build script is plain JS.
import { isStoreBuild, updaterConfig } from "../scripts/tauri-build-with-updater.mjs";
import { isStoreDistribution } from "../src/update/updateController";

describe("the Tauri updater build", () => {
  it("merges nothing into a build without an updater", () => {
    expect(updaterConfig({})).toBeNull();
    expect(updaterConfig({ FLARE_UPDATER_PUBKEY: " ", FLARE_UPDATER_ENDPOINTS: " , " })).toBeNull();
  });

  it("takes the key and the endpoints from the environment", () => {
    expect(updaterConfig({
      FLARE_UPDATER_PUBKEY: " key ",
      FLARE_UPDATER_ENDPOINTS: "https://a.example/{{target}}, https://b.example/{{target}}",
    })).toEqual({
      bundle: { createUpdaterArtifacts: true },
      plugins: { updater: { pubkey: "key", endpoints: ["https://a.example/{{target}}", "https://b.example/{{target}}"] } },
    });
  });

  it("refuses half a configuration instead of building an app that cannot update", () => {
    expect(() => updaterConfig({ FLARE_UPDATER_PUBKEY: "key" })).toThrow(/go together/);
    expect(() => updaterConfig({ FLARE_UPDATER_ENDPOINTS: "https://a.example" })).toThrow(/go together/);
  });

  it("leaves the updater out of a store build, whatever the environment holds", () => {
    const updater = { FLARE_UPDATER_PUBKEY: "key", FLARE_UPDATER_ENDPOINTS: "https://a.example" };

    expect(updaterConfig({ ...updater, VITE_FLARE_DISTRIBUTION: "appstore" })).toBeNull();
    expect(updaterConfig({ ...updater, VITE_FLARE_DISTRIBUTION: " msstore " })).toBeNull();
    expect(updaterConfig({ FLARE_UPDATER_PUBKEY: "key", VITE_FLARE_DISTRIBUTION: "appstore" })).toBeNull();
  });

  it("keeps the updater of a build no store ships", () => {
    const updater = { FLARE_UPDATER_PUBKEY: "key", FLARE_UPDATER_ENDPOINTS: "https://a.example" };

    for (const distribution of ["tauri", "direct", " ", ""]) {
      expect(updaterConfig({ ...updater, VITE_FLARE_DISTRIBUTION: distribution }), distribution).not.toBeNull();
    }
  });

  it("agrees with the page on what a store build is", () => {
    for (const distribution of ["appstore", "msstore", "play", "tauri", "direct", "web", " ", ""]) {
      expect(isStoreBuild({ VITE_FLARE_DISTRIBUTION: distribution }), distribution).toBe(isStoreDistribution(distribution));
    }
    expect(isStoreBuild({})).toBe(isStoreDistribution(undefined));
  });
});
