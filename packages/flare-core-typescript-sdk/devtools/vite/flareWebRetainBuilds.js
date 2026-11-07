#!/usr/bin/env node
/**
 * Carries earlier web builds into a new output. A rollback or a staged rollout goes back to an older build through its
 * manifest, so that build's `builds/<buildId>/` and its content-hashed files have to outlive the deployments after it.
 * A deployment that replaces the site drops them. Run this between the build and the deployment:
 *
 *   flare-web-retain-builds --previous <the output deployed now> [--out dist] [--keep 3]
 *   flare-web-retain-builds --first-deployment [--out dist]
 *
 * `--keep` counts earlier builds: the one in `--out` is not one of them. The order comes from `builds/history.json`,
 * written here, because timestamps do not survive every copy and pipelines name builds freely. A build that lost a file
 * cannot be rolled back to, so it is dropped and the next older one takes its place. A first deployment has nothing to
 * carry and has to say so: a `--previous` that does not exist is a wrong path, and treating it as a first deployment
 * would drop every build a rollback needs without a word.
 */
import { realpathSync, promises as fs } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";

import { ASSET_MANIFEST_FILE, BUILD_SOURCES_DIR } from "./flareWebUpdateVite.js";

const HISTORY_FILE = "history.json";
const DEFAULT_KEEP = 3;

async function readJson(file) {
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function exists(file) {
  return fs.access(file).then(() => true, () => false);
}

/**
 * The builds in an output, latest first: the one it serves, then its history, then whatever else is in `builds/`. The
 * last kind only exists in an output this tool never ran on; build ids start with the day, so their order will do.
 */
async function buildsLatestFirst(outputDir) {
  const sourcesDir = path.join(outputDir, BUILD_SOURCES_DIR);
  let entries;
  try {
    entries = await fs.readdir(sourcesDir, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const present = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);
  const served = await readJson(path.join(outputDir, ASSET_MANIFEST_FILE));
  const history = await readJson(path.join(sourcesDir, HISTORY_FILE));
  const ordered = [served?.buildId, ...(history?.builds ?? []), ...[...present].sort().reverse()];
  return [...new Set(ordered)].filter((buildId) => present.includes(buildId));
}

/** The files a build serves from their own address, relative to the output: every asset without a copy in `builds/`. */
function filesOutsideBuilds(manifest) {
  const marker = `${BUILD_SOURCES_DIR}/${manifest.buildId}/`;
  const pinned = manifest.assets.find((asset) => asset.source?.includes(marker));
  const base = pinned ? pinned.source.slice(0, pinned.source.indexOf(marker)) : "/";
  return manifest.assets.filter((asset) => !asset.source).map((asset) => asset.url.split("?")[0].slice(base.length));
}

/** Copies one build into `outDir`. A build that lacks a file is not copied at all; answers the files it lacks. */
async function carryBuild(previousDir, outDir, buildId) {
  const sources = `${BUILD_SOURCES_DIR}/${buildId}`;
  const manifest = await readJson(path.join(previousDir, sources, ASSET_MANIFEST_FILE));
  if (!manifest) return [`${sources}/${ASSET_MANIFEST_FILE}`];

  const toCopy = [];
  const missing = [];
  for (const file of filesOutsideBuilds(manifest)) {
    // The name carries the content's hash: the new build's file of that name is this very file.
    if (await exists(path.join(outDir, file))) continue;
    (await exists(path.join(previousDir, file)) ? toCopy : missing).push(file);
  }
  if (missing.length > 0) return missing;

  await fs.cp(path.join(previousDir, sources), path.join(outDir, sources), { recursive: true });
  for (const file of toCopy) {
    await fs.mkdir(path.dirname(path.join(outDir, file)), { recursive: true });
    await fs.copyFile(path.join(previousDir, file), path.join(outDir, file));
  }
  return [];
}

/**
 * Brings the latest `keep` earlier builds of `previousDir` into `outDir`, a finished build, and records the order for
 * the next deployment. Answers the build of `outDir`, the ids carried, latest first, and the builds dropped with what
 * each lacks.
 */
export async function retainWebBuilds({ previousDir, outDir, keep = DEFAULT_KEEP }) {
  if (!Number.isInteger(keep) || keep < 0) throw new Error(`keep must be a whole number: ${keep}`);
  if (previousDir !== null && !(await exists(previousDir))) {
    throw new Error(`${previousDir} does not exist: pass the output deployed now, or --first-deployment`);
  }
  const manifest = await readJson(path.join(outDir, ASSET_MANIFEST_FILE));
  if (!manifest) throw new Error(`${path.join(outDir, ASSET_MANIFEST_FILE)} is missing: run this on a finished build`);

  const current = manifest.buildId;
  const retained = [];
  const incomplete = [];
  for (const buildId of previousDir === null ? [] : await buildsLatestFirst(previousDir)) {
    if (retained.length === keep) break;
    // Built again under the same id: the new files are the build.
    if (buildId === current) continue;
    const missing = await carryBuild(previousDir, outDir, buildId);
    if (missing.length > 0) incomplete.push({ buildId, missing });
    else retained.push(buildId);
  }
  await fs.writeFile(
    path.join(outDir, BUILD_SOURCES_DIR, HISTORY_FILE),
    `${JSON.stringify({ builds: [current, ...retained] }, null, 2)}\n`,
  );
  return { current, retained, incomplete };
}

async function main() {
  const { values } = parseArgs({
    options: {
      previous: { type: "string" },
      "first-deployment": { type: "boolean", default: false },
      out: { type: "string", default: "dist" },
      keep: { type: "string", default: String(DEFAULT_KEEP) },
    },
  });
  const first = values["first-deployment"];
  if (Boolean(values.previous) === first) {
    throw new Error("usage: flare-web-retain-builds (--previous <dir> | --first-deployment) [--out dist] [--keep 3]");
  }
  const { current, retained, incomplete } = await retainWebBuilds({
    previousDir: first ? null : values.previous,
    outDir: values.out,
    keep: Number(values.keep),
  });
  console.log(`web builds: ${current}, and earlier: ${retained.join(" ") || "none"}`);
  for (const { buildId, missing } of incomplete) {
    console.warn(`web builds: dropped ${buildId}, it lacks ${missing.join(" ")}`);
  }
}

// Through `node_modules/.bin` or a linked package the script's path is a symlink; `import.meta.url` is the file itself.
if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
