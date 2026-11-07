#!/usr/bin/env node
// Writes the core SDK access configuration this bundle is built with (`FLARE_ACCESS_JSON`) to
// .generated/flare-access.json; index.js hands it to src/config/access.ts. Unset leaves it empty: a development
// bundle then connects to the local stack, a release bundle offers no sign-in.

const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const generatedDir = path.join(appRoot, '.generated');
const generatedFile = path.join(generatedDir, 'flare-access.json');

const json = (process.env.FLARE_ACCESS_JSON || '').trim();
if (json) {
  let parsed;
  try {
    parsed = JSON.parse(json);
  } catch (error) {
    console.error(`[flare-core-rn-app] FLARE_ACCESS_JSON is not valid JSON: ${error.message}`);
    process.exit(1);
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    console.error('[flare-core-rn-app] FLARE_ACCESS_JSON must be the SDK access object');
    process.exit(1);
  }
}

fs.mkdirSync(generatedDir, { recursive: true });
fs.writeFileSync(generatedFile, `${JSON.stringify({ json }, null, 2)}\n`);
console.log(json
  ? '[flare-core-rn-app] access configuration synced from FLARE_ACCESS_JSON.'
  : '[flare-core-rn-app] FLARE_ACCESS_JSON is unset: a development bundle connects to the local stack.');
