import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  AccessConfigError,
  LOCAL_DEVELOPMENT_ACCESS,
  buildAccessConfig,
  resolveAccessConfig,
} from '../src/config/access.ts';

const twoPoints = {
  trustMode: 'development',
  developmentEndpoints: {
    wsUrl: 'ws://10.0.2.2:60051',
    coreApiUrl: 'http://10.0.2.2:50050',
    accessPoints: [{ id: 'dev-b', wsUrl: 'ws://10.0.2.2:61051', coreApiUrl: 'http://10.0.2.2:51050' }],
  },
};

test('the injected access configuration goes to the core as it is', () => {
  assert.deepEqual(resolveAccessConfig({ json: ` ${JSON.stringify(twoPoints)} ` }), twoPoints);
  const seed = { bootstrapId: 'flare-core', trustRoots: [{ keyId: 'root-2026', publicKey: 'AAAA' }], seed: '{}', trustMode: 'production' };
  assert.deepEqual(resolveAccessConfig({ json: JSON.stringify(seed), localDefaults: LOCAL_DEVELOPMENT_ACCESS }), seed);
});

test('only a development bundle falls back to the local stack, on the ports the core servers listen on', () => {
  assert.deepEqual(resolveAccessConfig({ localDefaults: LOCAL_DEVELOPMENT_ACCESS }), LOCAL_DEVELOPMENT_ACCESS);
  assert.deepEqual(LOCAL_DEVELOPMENT_ACCESS.developmentEndpoints, {
    wsUrl: 'ws://127.0.0.1:60051',
    coreApiUrl: 'http://127.0.0.1:50050',
    mediaUrl: 'http://127.0.0.1:50050',
  });
  assert.throws(() => resolveAccessConfig({}), AccessConfigError);
  assert.throws(() => resolveAccessConfig({ json: '[]', localDefaults: LOCAL_DEVELOPMENT_ACCESS }), AccessConfigError);
  assert.throws(() => resolveAccessConfig({ json: '{oops', localDefaults: LOCAL_DEVELOPMENT_ACCESS }), /not valid JSON/);
});

test('the bundle reads what index.js handed over, and __DEV__ decides the fallback', () => {
  const host = globalThis as { __FLARE_ACCESS_JSON__?: string; __DEV__?: boolean };
  try {
    host.__FLARE_ACCESS_JSON__ = JSON.stringify(twoPoints);
    host.__DEV__ = false;
    assert.deepEqual(buildAccessConfig(), twoPoints);
    host.__FLARE_ACCESS_JSON__ = '';
    assert.throws(() => buildAccessConfig(), AccessConfigError);
    host.__DEV__ = true;
    assert.deepEqual(buildAccessConfig(), LOCAL_DEVELOPMENT_ACCESS);
  } finally {
    delete host.__FLARE_ACCESS_JSON__;
    delete host.__DEV__;
  }
});
