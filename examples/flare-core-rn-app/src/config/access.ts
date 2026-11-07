/**
 * Where this build connects: the core SDK's access configuration `access`, given when the bundle is built. The sign-in
 * screen has no server settings.
 *
 * - `FLARE_ACCESS_JSON` (environment of `npm run start` / `ios` / `android` / `bundle:*`): the `access` object as
 *   JSON. `scripts/sync-access-config.js` writes it to `.generated/flare-access.json` and `index.js` hands it over as
 *   `globalThis.__FLARE_ACCESS_JSON__`. A release bundle carries a signed seed; local runs carry development
 *   endpoints `{"trustMode":"development","developmentEndpoints":{...}}`, with a second access point under
 *   `developmentEndpoints.accessPoints`. On the Android emulator the host machine is `10.0.2.2` (or forward the
 *   ports with `adb reverse`).
 * - Without it only a development bundle (`__DEV__`) falls back to the local stack below; a release bundle without it
 *   says so instead of quietly connecting to development endpoints.
 */
import type { AccessConfig } from '@flare-im/sdk/api';

/** The local stack's development endpoints, on the ports the repository's servers listen on. */
export const LOCAL_DEVELOPMENT_ACCESS = {
  trustMode: 'development',
  developmentEndpoints: {
    // flare-core-server/config/services/access-gateway.toml (port = 60051)
    wsUrl: 'ws://127.0.0.1:60051',
    // flare-core-server/config/services/api-gateway.toml (port = 50050); media goes through the same API gateway
    coreApiUrl: 'http://127.0.0.1:50050',
    mediaUrl: 'http://127.0.0.1:50050',
  },
} as const satisfies AccessConfig;

/** The build cannot connect anywhere: no access configuration, or one that is not a JSON object. */
export class AccessConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AccessConfigError';
  }
}

export type AccessBuildInput = {
  /** `FLARE_ACCESS_JSON` as the bundle was built with. */
  json?: string;
  /** The local stack, handed in for a development bundle only. */
  localDefaults?: Readonly<AccessConfig>;
};

/** The `access` object of the SDK configuration; throws {@link AccessConfigError} when there is none. */
export function resolveAccessConfig(input: AccessBuildInput): AccessConfig {
  const raw = input.json?.trim();
  if (raw) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      throw new AccessConfigError(`FLARE_ACCESS_JSON is not valid JSON: ${(error as Error).message}`);
    }
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new AccessConfigError('FLARE_ACCESS_JSON must be the SDK access object');
    }
    return parsed as AccessConfig;
  }
  if (input.localDefaults) return JSON.parse(JSON.stringify(input.localDefaults)) as AccessConfig;
  throw new AccessConfigError(
    'This bundle has no access configuration: build it with FLARE_ACCESS_JSON (a signed seed, or development endpoints)',
  );
}

/** The access configuration this bundle was built with. Throws {@link AccessConfigError} when it has none. */
export function buildAccessConfig(): AccessConfig {
  const host = globalThis as { __FLARE_ACCESS_JSON__?: unknown; __DEV__?: unknown };
  return resolveAccessConfig({
    json: typeof host.__FLARE_ACCESS_JSON__ === 'string' ? host.__FLARE_ACCESS_JSON__ : undefined,
    localDefaults: host.__DEV__ === true ? LOCAL_DEVELOPMENT_ACCESS : undefined,
  });
}
