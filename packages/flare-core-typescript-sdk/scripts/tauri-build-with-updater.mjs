#!/usr/bin/env node
/**
 * `tauri build`, with the updater when this build has one. `tauri.conf.json` holds no key: the updater goes in through
 * `--config`, from the environment of the build.
 *
 *   FLARE_UPDATER_PUBKEY      content of the updater's public key (`tauri signer generate`), not a path
 *   FLARE_UPDATER_ENDPOINTS   update endpoints, comma separated
 *
 * `tauri build` reads the private key itself (TAURI_SIGNING_PRIVATE_KEY, TAURI_SIGNING_PRIVATE_KEY_PASSWORD). With
 * neither variable set the app is built without an updater: the Rust side finds no `plugins.updater` and leaves the
 * plugin out, and the page, without VITE_FLARE_UPDATER_ENABLED, offers the website instead. Arguments go to `tauri build`.
 *
 * A store build (VITE_FLARE_DISTRIBUTION names a store) never has an updater, whatever those variables hold: stores
 * forbid an app to update itself. The variable has to be in the environment of the build, a `.env` file does not reach
 * this script.
 */
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

/** No store serves these channels; `isStoreDistribution` of `@flare-im/sdk/update` draws the same line for the page. */
const NON_STORE_DISTRIBUTIONS = new Set(["direct", "web", "tauri", "electron"]);

export function isStoreBuild(env) {
  const distribution = String(env.VITE_FLARE_DISTRIBUTION ?? "").trim();
  return distribution !== "" && !NON_STORE_DISTRIBUTIONS.has(distribution);
}

/** What to merge into the Tauri configuration; null for a build without an updater. */
export function updaterConfig(env) {
  if (isStoreBuild(env)) return null;
  const pubkey = String(env.FLARE_UPDATER_PUBKEY ?? "").trim();
  const endpoints = String(env.FLARE_UPDATER_ENDPOINTS ?? "").split(",").map((endpoint) => endpoint.trim()).filter(Boolean);
  if (!pubkey && endpoints.length === 0) return null;
  if (!pubkey || endpoints.length === 0) {
    throw new Error("FLARE_UPDATER_PUBKEY and FLARE_UPDATER_ENDPOINTS go together");
  }
  return { bundle: { createUpdaterArtifacts: true }, plugins: { updater: { pubkey, endpoints } } };
}

function main() {
  const config = updaterConfig(process.env);
  const args = ["tauri", "build", ...(config ? ["--config", JSON.stringify(config)] : []), ...process.argv.slice(2)];
  const env = config ? { ...process.env, VITE_FLARE_UPDATER_ENABLED: "1" } : process.env;
  const result = spawnSync("npx", args, { stdio: "inherit", env, shell: process.platform === "win32" });
  process.exit(result.status ?? 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
