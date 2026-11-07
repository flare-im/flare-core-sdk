/**
 * The web update build. After a production build it leaves in the output:
 *
 * - `asset-manifest.json`, the build's `flare.web-assets.v1` manifest, also under `builds/<buildId>/`: the release
 *   manifest's `urls` point there, its `sha256` is this file's hash;
 * - `builds/<buildId>/`, a copy of every listed file whose name carries no content hash. The next deployment overwrites
 *   those at their own address, so a rollback fetches them from here. Deployments keep `builds/` and hashed assets,
 *   `flareWebRetainBuilds.js` carries them from one output to the next;
 * - `sw.js` at the site root, the same script for every build: it learns its build from its own URL.
 *
 * `index.html`, the content-hashed `assets/` and the `pinned` directories are listed. Everything else (emoji and
 * sticker art, public files) stays out of the manifest and goes past the Service Worker unchanged.
 */
import crypto from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

export const ASSET_MANIFEST_FILE = "asset-manifest.json";
const ASSET_MANIFEST_SCHEMA = "flare.web-assets.v1";
const SERVICE_WORKER_FILE = "sw.js";
export const BUILD_SOURCES_DIR = "builds";
const INDEX_FILE = "index.html";
const SAFE_BUILD_ID = /^[A-Za-z0-9._-]+$/;

/**
 * The id of this build: `VITE_FLARE_WEB_BUILD_ID` when the release pipeline names it, else the day and a random
 * suffix. It goes into the bundle, so it cannot be a hash of the bundle.
 */
export function resolveWebBuildId(env = {}, now = new Date()) {
  const given = String(env.VITE_FLARE_WEB_BUILD_ID ?? "").trim();
  if (given && !SAFE_BUILD_ID.test(given)) {
    throw new Error(`VITE_FLARE_WEB_BUILD_ID must be letters, digits, dot, dash or underscore: ${given}`);
  }
  if (given) return given;
  const day = now.toISOString().slice(0, 10).replaceAll("-", "");
  return `${day}-${crypto.randomBytes(4).toString("hex")}`;
}

async function listFiles(root, prefix = "") {
  let entries;
  try {
    entries = await fs.readdir(path.join(root, prefix), { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const nested = await Promise.all(entries.map((entry) => {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) return listFiles(root, relativePath);
    return entry.isFile() ? [relativePath] : [];
  }));
  return nested.flat();
}

/** The files `index.html` loads, relative to the output: with the wasm runtime they are the shell. */
function filesTheShellLoads(indexHtml, base) {
  const loaded = new Set();
  for (const [, reference] of indexHtml.matchAll(/\b(?:src|href)=["']([^"']+)["']/g)) {
    const pathOnly = reference.split(/[?#]/)[0];
    if (/^[a-z][a-z0-9+.-]*:|^\/\//i.test(pathOnly)) continue;
    const relative = pathOnly.startsWith(base) ? pathOnly.slice(base.length) : pathOnly.replace(/^\.?\//, "");
    if (relative) loaded.add(relative);
  }
  return loaded;
}

/**
 * Writes the manifest and the per-build copies into `outDir`, and answers the manifest with its hash.
 *
 * `pinned` are directories of `outDir` holding files of this build with no content hash in their name; `assetQueries`
 * are the query strings the page asks for some of them with, by path relative to `outDir`.
 */
export async function writeWebUpdateFiles({ outDir, base = "/", buildId, assetsDir = "assets", pinned = [], assetQueries = {} }) {
  const sourcesDir = `${BUILD_SOURCES_DIR}/${buildId}`;
  const indexHtml = await fs.readFile(path.join(outDir, INDEX_FILE), "utf8");
  const shell = filesTheShellLoads(indexHtml, base);

  const hashed = (await listFiles(outDir, assetsDir)).filter((file) => !file.endsWith(".map"));
  const unhashed = [INDEX_FILE, ...(await Promise.all(pinned.map((dir) => listFiles(outDir, dir)))).flat()];
  const unhashedFiles = new Set(unhashed);

  const assets = [];
  for (const file of [...unhashed, ...hashed].sort()) {
    const body = await fs.readFile(path.join(outDir, file));
    const pinnedHere = unhashedFiles.has(file);
    if (pinnedHere) {
      const copy = path.join(outDir, sourcesDir, file);
      await fs.mkdir(path.dirname(copy), { recursive: true });
      await fs.writeFile(copy, body);
    }
    assets.push({
      url: `${base}${file}${assetQueries[file] ?? ""}`,
      sha256: crypto.createHash("sha256").update(body).digest("hex"),
      size: body.length,
      ...(pinnedHere ? { source: `${base}${sourcesDir}/${file}` } : {}),
      ...(pinnedHere || shell.has(file) || file.endsWith(".wasm") ? { precache: true } : {}),
    });
  }

  const manifest = { schema: ASSET_MANIFEST_SCHEMA, buildId, assets };
  const text = `${JSON.stringify(manifest, null, 2)}\n`;
  await fs.mkdir(path.join(outDir, sourcesDir), { recursive: true });
  await fs.writeFile(path.join(outDir, ASSET_MANIFEST_FILE), text);
  await fs.writeFile(path.join(outDir, sourcesDir, ASSET_MANIFEST_FILE), text);
  return { manifest, sha256: crypto.createHash("sha256").update(text).digest("hex") };
}

/** `entry` bundled into one classic script at the output's root: a Service Worker cannot share the page's chunks. */
function buildServiceWorker(viteBuild, config, entry) {
  return viteBuild({
    configFile: false,
    root: config.root,
    base: config.base,
    mode: config.mode,
    publicDir: false,
    logLevel: "warn",
    resolve: { alias: config.resolve.alias },
    build: {
      outDir: config.build.outDir,
      emptyOutDir: false,
      sourcemap: false,
      lib: { entry, name: "flareServiceWorker", formats: ["iife"], fileName: () => SERVICE_WORKER_FILE },
    },
  });
}

/**
 * The Vite plugin, for production builds only: the dev server has no manifest and no worker, and no build id either.
 * It defines `__FLARE_WEB_BUILD_ID__` for `webAppInfoFromBuild`. `viteBuild` is Vite's `build`, handed in because this
 * package does not depend on Vite; `serviceWorkerEntry` is relative to the app (default `src/sw.ts`). Runs after every
 * other plugin has written its files: the wasm runtime is copied in `writeBundle`.
 */
export function flareWebUpdateBuild({ buildId, viteBuild, serviceWorkerEntry = "src/sw.ts", pinned = [], assetQueries = {} }) {
  let config;
  let written = false;
  return {
    name: "flare-web-update-build",
    apply: "build",
    config() {
      return { define: { __FLARE_WEB_BUILD_ID__: JSON.stringify(buildId) } };
    },
    configResolved(resolved) {
      config = resolved;
    },
    writeBundle() {
      written = true;
    },
    closeBundle: {
      order: "post",
      sequential: true,
      async handler() {
        // A failed build closes too, with nothing to describe.
        if (!written) return;
        const outDir = path.resolve(config.root, config.build.outDir);
        await buildServiceWorker(viteBuild, config, path.resolve(config.root, serviceWorkerEntry));
        const { sha256 } = await writeWebUpdateFiles({
          outDir,
          base: config.base,
          buildId,
          assetsDir: config.build.assetsDir,
          pinned,
          assetQueries,
        });
        config.logger.info(`web update: build ${buildId}, ${ASSET_MANIFEST_FILE} sha256 ${sha256}`);
      },
    },
  };
}
