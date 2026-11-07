import { describe, expect, it } from "vitest";
import { AccessConfigError, LOCAL_DEVELOPMENT_ACCESS, resolveAccessConfig } from "./access";

describe("the access configuration a reference build connects with", () => {
  it("takes injected development endpoints as they are, a second access point and QUIC included", () => {
    const access = {
      trustMode: "development",
      developmentEndpoints: {
        wsUrl: "ws://127.0.0.1:60051",
        quicUrl: "quic://127.0.0.1:60052",
        coreApiUrl: "http://127.0.0.1:50050",
        mediaUrl: "http://127.0.0.1:50050",
        accessPoints: [{ id: "dev-b", wsUrl: "ws://127.0.0.1:61051", coreApiUrl: "http://127.0.0.1:51050" }],
      },
    };
    expect(resolveAccessConfig({ json: ` ${JSON.stringify(access)} `, localDefaults: undefined })).toEqual(access);
  });

  it("takes a signed production seed the same way, even on the dev server", () => {
    const access = { bootstrapId: "flare-core", trustRoots: [{ keyId: "root-2026", publicKey: "AAAA" }], seed: "{}", trustMode: "production" };
    expect(resolveAccessConfig({ json: JSON.stringify(access), localDefaults: LOCAL_DEVELOPMENT_ACCESS })).toEqual(access);
  });

  it("falls back to the local stack only when the dev server hands it in, as a copy", () => {
    const local = resolveAccessConfig({ localDefaults: LOCAL_DEVELOPMENT_ACCESS });
    expect(local).toEqual(LOCAL_DEVELOPMENT_ACCESS);
    expect(local).not.toBe(LOCAL_DEVELOPMENT_ACCESS);
    expect(resolveAccessConfig({ json: "   ", localDefaults: LOCAL_DEVELOPMENT_ACCESS })).toEqual(LOCAL_DEVELOPMENT_ACCESS);
  });

  it("says so instead of connecting to development endpoints when a production build has none", () => {
    expect(() => resolveAccessConfig({ localDefaults: undefined })).toThrow(AccessConfigError);
    expect(() => resolveAccessConfig({ json: "", localDefaults: undefined })).toThrow(/VITE_FLARE_ACCESS_JSON/);
  });

  it("rejects an injected value that is not the access object", () => {
    expect(() => resolveAccessConfig({ json: "{not json", localDefaults: LOCAL_DEVELOPMENT_ACCESS })).toThrow(/not valid JSON/);
    expect(() => resolveAccessConfig({ json: "[]", localDefaults: LOCAL_DEVELOPMENT_ACCESS })).toThrow(/access object/);
    expect(() => resolveAccessConfig({ json: "\"ws://127.0.0.1:60051\"", localDefaults: LOCAL_DEVELOPMENT_ACCESS })).toThrow(AccessConfigError);
  });

  it("keeps the local stack on the ports the core servers listen on", () => {
    // access-gateway.toml port 60051; api-gateway.toml port 50050 (core API and media).
    expect(LOCAL_DEVELOPMENT_ACCESS).toEqual({
      trustMode: "development",
      developmentEndpoints: {
        wsUrl: "ws://127.0.0.1:60051",
        coreApiUrl: "http://127.0.0.1:50050",
        mediaUrl: "http://127.0.0.1:50050",
      },
    });
  });
});
