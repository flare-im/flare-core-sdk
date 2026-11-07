/**
 * Where this build connects: the core SDK's access configuration `access`, given at build time only. The sign-in
 * page has no server settings.
 *
 * - `VITE_FLARE_ACCESS_JSON`: the `access` object as JSON. A release build carries a signed seed (`bootstrapId`,
 *   `trustRoots`, `seed`, `trustMode: "production"`); local runs and labs carry development endpoints
 *   `{"trustMode":"development","developmentEndpoints":{...}}`, with a second access point of the same cell under
 *   `developmentEndpoints.accessPoints`. IM, core HTTP and media all pick their access point from it.
 * - Without it only the dev server falls back to the local stack below; a production build without it says so
 *   instead of quietly connecting to development endpoints.
 *
 * The module is pure (the build-time values come in as arguments) so its tests import it directly.
 */
import type { AccessConfig } from "@flare-im/sdk/web";

/** The local stack's development endpoints, on the ports the repository's servers listen on. */
export const LOCAL_DEVELOPMENT_ACCESS = {
  trustMode: "development",
  developmentEndpoints: {
    // flare-core-server/config/services/access-gateway.toml (port = 60051)
    wsUrl: "ws://127.0.0.1:60051",
    // flare-core-server/config/services/api-gateway.toml (port = 50050); media goes through the same API gateway
    coreApiUrl: "http://127.0.0.1:50050",
    mediaUrl: "http://127.0.0.1:50050",
  },
} as const satisfies AccessConfig;

/** The build cannot connect anywhere: no access configuration, or one that is not a JSON object. */
export class AccessConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AccessConfigError";
  }
}

export interface AccessBuildInput {
  /** `VITE_FLARE_ACCESS_JSON` as the build saw it. */
  json?: string;
  /**
   * The local stack ({@link LOCAL_DEVELOPMENT_ACCESS}), handed in on the dev server only as
   * `import.meta.env.DEV ? LOCAL_DEVELOPMENT_ACCESS : undefined`: a production bundle does not even carry it.
   */
  localDefaults?: Readonly<AccessConfig>;
}

/** The `access` object of the SDK configuration for this build; throws {@link AccessConfigError} when there is none. */
export function resolveAccessConfig(input: AccessBuildInput): AccessConfig {
  const raw = input.json?.trim();
  if (raw) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      throw new AccessConfigError(`VITE_FLARE_ACCESS_JSON is not valid JSON: ${(error as Error).message}`);
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new AccessConfigError("VITE_FLARE_ACCESS_JSON must be the SDK access object");
    }
    return parsed as AccessConfig;
  }
  if (input.localDefaults) return JSON.parse(JSON.stringify(input.localDefaults)) as AccessConfig;
  throw new AccessConfigError(
    "This build has no access configuration: build it with VITE_FLARE_ACCESS_JSON (a signed seed, or development endpoints)",
  );
}

/** The access configuration this build was made with. Throws {@link AccessConfigError} when it has none. */
export function buildAccessConfig(): AccessConfig {
  return resolveAccessConfig({
    json: import.meta.env.VITE_FLARE_ACCESS_JSON,
    localDefaults: import.meta.env.DEV ? LOCAL_DEVELOPMENT_ACCESS : undefined,
  });
}
