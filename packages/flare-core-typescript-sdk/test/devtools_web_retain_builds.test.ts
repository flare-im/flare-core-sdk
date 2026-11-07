import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { afterEach, describe, expect, it } from "vitest";

// @ts-expect-error The helpers are plain JS.
import { writeWebUpdateFiles } from "../devtools/vite/flareWebUpdateVite.js";
// @ts-expect-error The helpers are plain JS.
import { retainWebBuilds } from "../devtools/vite/flareWebRetainBuilds.js";

const temporaryDirs: string[] = [];

function temporaryDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "flare-web-retain-"));
  temporaryDirs.push(dir);
  return dir;
}

/** A finished build of its own: every build has its entry chunk, and all of them share a vendor chunk. */
async function build(buildId: string, base = "/"): Promise<string> {
  const outDir = temporaryDir();
  const files: Record<string, string> = {
    "index.html": `<script type="module" src="${base}assets/index-${buildId}.js"></script>`,
    [`assets/index-${buildId}.js`]: `entry of ${buildId}`,
    "assets/vendor-shared.js": "vendor",
    "flare-core-wasm/flare_im_core_sdk_bg.wasm": `binary of ${buildId}`,
  };
  for (const [file, body] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(outDir, file)), { recursive: true });
    fs.writeFileSync(path.join(outDir, file), body);
  }
  await writeWebUpdateFiles({ outDir, base, buildId, pinned: ["flare-core-wasm"] });
  return outDir;
}

/** The output left by deploying these builds in turn, each carried over from the one before. */
async function deployments(buildIds: string[], keep?: number): Promise<string> {
  let deployed = "";
  for (const buildId of buildIds) {
    const outDir = await build(buildId);
    if (deployed) await retainWebBuilds({ previousDir: deployed, outDir, keep });
    deployed = outDir;
  }
  return deployed;
}

const buildsIn = (outDir: string) => fs.readdirSync(path.join(outDir, "builds"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

const history = (outDir: string): string[] => JSON.parse(fs.readFileSync(path.join(outDir, "builds/history.json"), "utf8")).builds;

afterEach(() => {
  for (const dir of temporaryDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

describe("retainWebBuilds", () => {
  it("brings over all a rollback fetches: the manifest, the pinned copies and the hashed files", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b2");

    const result = await retainWebBuilds({ previousDir, outDir });

    expect(result).toEqual({ current: "b2", retained: ["b1"], incomplete: [] });
    expect(fs.existsSync(path.join(outDir, "builds/b1/asset-manifest.json"))).toBe(true);
    expect(fs.readFileSync(path.join(outDir, "builds/b1/flare-core-wasm/flare_im_core_sdk_bg.wasm"), "utf8")).toBe("binary of b1");
    expect(fs.readFileSync(path.join(outDir, "assets/index-b1.js"), "utf8")).toBe("entry of b1");
  });

  it("leaves what the new build serves as it was", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b2");
    const manifest = fs.readFileSync(path.join(outDir, "asset-manifest.json"), "utf8");
    const index = fs.readFileSync(path.join(outDir, "index.html"), "utf8");

    await retainWebBuilds({ previousDir, outDir });

    expect(fs.readFileSync(path.join(outDir, "asset-manifest.json"), "utf8")).toBe(manifest);
    expect(fs.readFileSync(path.join(outDir, "index.html"), "utf8")).toBe(index);
    expect(fs.readFileSync(path.join(outDir, "flare-core-wasm/flare_im_core_sdk_bg.wasm"), "utf8")).toBe("binary of b2");
  });

  it("keeps three earlier builds by default, the current one not counted", async () => {
    const outDir = await deployments(["b1", "b2", "b3", "b4", "b5", "b6"]);

    expect(buildsIn(outDir)).toEqual(["b3", "b4", "b5", "b6"]);
    expect(history(outDir)).toEqual(["b6", "b5", "b4", "b3"]);
    expect(fs.existsSync(path.join(outDir, "assets/index-b3.js"))).toBe(true);
    expect(fs.existsSync(path.join(outDir, "assets/index-b2.js"))).toBe(false);
  });

  it("keeps as many as asked, none included", async () => {
    expect(buildsIn(await deployments(["b1", "b2", "b3"], 1))).toEqual(["b2", "b3"]);
    expect(buildsIn(await deployments(["b1", "b2", "b3"], 0))).toEqual(["b3"]);
  });

  it("goes by the deployments, not by the ids or the file times", async () => {
    const previousDir = await deployments(["zulu", "alpha", "mike"]);
    const longAgo = new Date("2020-01-01T00:00:00Z");
    for (const buildId of buildsIn(previousDir)) fs.utimesSync(path.join(previousDir, "builds", buildId), longAgo, longAgo);
    const outDir = await build("next");

    const { retained } = await retainWebBuilds({ previousDir, outDir, keep: 2 });

    expect(retained).toEqual(["mike", "alpha"]);
  });

  it("takes the build the previous output serves first, even if its history is stale", async () => {
    const previousDir = await deployments(["b1", "b2"]);
    fs.writeFileSync(path.join(previousDir, "builds/history.json"), JSON.stringify({ builds: ["b1"] }));
    const outDir = await build("b3");

    expect((await retainWebBuilds({ previousDir, outDir, keep: 1 })).retained).toEqual(["b2"]);
  });

  it("does not let an earlier build of the same id replace the new one", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b1");
    fs.writeFileSync(path.join(previousDir, "builds/b1/index.html"), "the old one");
    const index = fs.readFileSync(path.join(outDir, "builds/b1/index.html"), "utf8");

    const { retained } = await retainWebBuilds({ previousDir, outDir });

    expect(retained).toEqual([]);
    expect(fs.readFileSync(path.join(outDir, "builds/b1/index.html"), "utf8")).toBe(index);
  });

  it("carries nothing on a first deployment, and still starts the history", async () => {
    const outDir = await build("b1");

    const result = await retainWebBuilds({ previousDir: null, outDir });

    expect(result).toEqual({ current: "b1", retained: [], incomplete: [] });
    expect(history(outDir)).toEqual(["b1"]);
  });

  it("refuses a previous output that does not exist, instead of dropping every earlier build", async () => {
    const outDir = await build("b1");

    await expect(retainWebBuilds({ previousDir: path.join(outDir, "no-such-output"), outDir })).rejects.toThrow(
      /does not exist/,
    );
  });

  it("drops a build that lost a file, and the next older one takes its place", async () => {
    const previousDir = await deployments(["b1", "b2", "b3"]);
    fs.rmSync(path.join(previousDir, "assets/index-b2.js"));
    const outDir = await build("b4");

    const result = await retainWebBuilds({ previousDir, outDir, keep: 2 });

    expect(result.retained).toEqual(["b3", "b1"]);
    expect(result.incomplete).toEqual([{ buildId: "b2", missing: ["assets/index-b2.js"] }]);
    expect(buildsIn(outDir)).toEqual(["b1", "b3", "b4"]);
    expect(history(outDir)).toEqual(["b4", "b3", "b1"]);
  });

  it("drops a directory that holds no manifest", async () => {
    const previousDir = await build("b1");
    fs.mkdirSync(path.join(previousDir, "builds/stray"));
    const outDir = await build("b2");

    const result = await retainWebBuilds({ previousDir, outDir });

    expect(result.retained).toEqual(["b1"]);
    expect(result.incomplete).toEqual([{ buildId: "stray", missing: ["builds/stray/asset-manifest.json"] }]);
  });

  it("does not take a hashed file from the previous output when the new build has it", async () => {
    const previousDir = await build("b1");
    fs.rmSync(path.join(previousDir, "assets/vendor-shared.js"));
    const outDir = await build("b2");

    const result = await retainWebBuilds({ previousDir, outDir });

    expect(result.retained).toEqual(["b1"]);
  });

  it("follows the deploy base the earlier build was made for", async () => {
    const previousDir = await build("b1", "/app/");
    const outDir = await build("b2", "/app/");

    await retainWebBuilds({ previousDir, outDir });

    expect(fs.readFileSync(path.join(outDir, "assets/index-b1.js"), "utf8")).toBe("entry of b1");
  });

  it("refuses a directory that is not a finished build, and a count that is not one", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b2");

    await expect(retainWebBuilds({ previousDir, outDir: temporaryDir() })).rejects.toThrow(/asset-manifest\.json/);
    await expect(retainWebBuilds({ previousDir, outDir, keep: -1 })).rejects.toThrow(/keep/);
    await expect(retainWebBuilds({ previousDir, outDir, keep: Number("many") })).rejects.toThrow(/keep/);
  });
});

describe("flare-web-retain-builds", () => {
  const script = fileURLToPath(new URL("../devtools/vite/flareWebRetainBuilds.js", import.meta.url));
  const run = (command: string, ...args: string[]) => execFileSync(process.execPath, [command, ...args], { encoding: "utf8", stdio: "pipe" });

  it("runs from the command line", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b2");

    const printed = run(script, "--previous", previousDir, "--out", outDir, "--keep", "1");

    expect(printed).toContain("b2");
    expect(buildsIn(outDir)).toEqual(["b1", "b2"]);
  });

  it("runs through the symlink npm leaves in node_modules/.bin", async () => {
    const previousDir = await build("b1");
    const outDir = await build("b2");
    const link = path.join(temporaryDir(), "flare-web-retain-builds");
    fs.symlinkSync(script, link);

    run(link, "--previous", previousDir, "--out", outDir);

    expect(buildsIn(outDir)).toEqual(["b1", "b2"]);
  });

  it("fails without --previous or --first-deployment, and with both", () => {
    expect(() => run(script)).toThrow(/usage/);
    expect(() => run(script, "--previous", "/srv/site", "--first-deployment")).toThrow(/usage/);
  });
});
