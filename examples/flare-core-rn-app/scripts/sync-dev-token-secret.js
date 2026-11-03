#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const generatedDir = path.join(appRoot, '.generated');
const generatedFile = path.join(generatedDir, 'dev-token-secret.json');
const defaultSecretFile = path.resolve(appRoot, '../../../flare-core-server/logs/.dev-token-secret');
const secretFile = process.env.FLARE_RN_DEV_TOKEN_SECRET_FILE || defaultSecretFile;

function readSecret() {
  const envSecret = process.env.FLARE_RN_DEV_TOKEN_SECRET || process.env.VITE_FLARE_TOKEN_SECRET;
  if (envSecret && envSecret.trim()) return { secret: envSecret.trim(), source: 'env' };
  if (fs.existsSync(secretFile)) {
    const secret = fs.readFileSync(secretFile, 'utf8').trim();
    if (secret) return { secret, source: secretFile };
  }
  return { secret: '', source: '' };
}

const { secret, source } = readSecret();
fs.mkdirSync(generatedDir, { recursive: true });
fs.writeFileSync(
  generatedFile,
  `${JSON.stringify({ secret, source }, null, 2)}\n`,
);

if (secret) {
  console.log(`[flare-core-rn-app] dev token secret synced from ${source}.`);
} else {
  console.warn('[flare-core-rn-app] dev token secret is missing; start flare-im-core or set FLARE_RN_DEV_TOKEN_SECRET.');
}
