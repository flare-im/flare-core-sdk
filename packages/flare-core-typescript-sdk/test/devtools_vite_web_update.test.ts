import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { afterEach, describe, expect, it, vi } from "vitest";

// @ts-expect-error The helper is plain JS; its types live in src/devtools/vite.
import { flareWebUpdateBuild, resolveWebBuildId, writeWebUpdateFiles } from "../devtools/vite/flareWebUpdateVite.js";
import { parseWebAssetManifest, type WebAsset } from "../src/update/webBundle";

const temporaryDirs: string[] = [];

function output(files: Record<string, string>): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "flare-web-update-"));
  temporaryDirs.push(dir);
  for (const [file, body] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
    fs.writeFileSync(path.join(dir, file), body);
  }
  return dir;
}

const sha256 = (body: string | Buffer) => crypto.createHash("sha256").update(body).digest("hex");

const INDEX = `<!doctype html><script type="module" crossorigin src="/assets/index-aa.js"></script>
<link rel="modulepreload" href="/assets/vendor-bb.js"><link rel="stylesheet" href="/assets/index-cc.css">
<link rel="icon" href="https://cdn.example/favicon.ico">`;

function site() {
  return output({
    "index.html": INDEX,
    "assets/index-aa.js": "entry",
    "assets/vendor-bb.js": "vendor",
    "assets/index-cc.css": "css",
    "assets/settings-dd.js": "lazy",
    "assets/settings-dd.js.map": "map",
    "assets/core_bg-ee.wasm": "wasm",
    "flare-core-wasm/flare_im_core_sdk.js": "glue",
    "flare-core-wasm/flare_im_core_sdk_bg.wasm": "binary",
    "flare-core-wasm/snippets/crate-1/inline0.js": "snippet",
    "flare-im-ui-assets/emoji/smile.webp": "art",
  });
}

afterEach(() => {
  for (const dir of temporaryDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

describe("writeWebUpdateFiles", () => {
  async function written(outDir: string, base = "/") {
    const result = await writeWebUpdateFiles({
      outDir,
      base,
      buildId: "20261105-abc",
      pinned: ["flare-core-wasm"],
      assetQueries: {
        "flare-core-wasm/flare_im_core_sdk.js": "?v=9b1e",
        "flare-core-wasm/flare_im_core_sdk_bg.wasm": "?v=9b1e",
      },
    });
    const text = fs.readFileSync(path.join(outDir, "asset-manifest.json"), "utf8");
    const manifest = parseWebAssetManifest(text);
    const byUrl = new Map<string, WebAsset>(manifest.assets.map((asset) => [asset.url, asset]));
    return { ...result, text, manifest, byUrl };
  }

  it("writes a manifest the Service Worker reads, and answers its hash", async () => {
    const { manifest, sha256: hash, text } = await written(site());

    expect(manifest.buildId).toBe("20261105-abc");
    expect(hash).toBe(sha256(text));
  });

  it("describes each file by what the page asks for and what the file holds", async () => {
    const { byUrl } = await written(site());

    expect(byUrl.get("/assets/index-aa.js")).toEqual({
      url: "/assets/index-aa.js",
      sha256: sha256("entry"),
      size: 5,
      precache: true,
    });
    expect(byUrl.get("/flare-core-wasm/flare_im_core_sdk_bg.wasm?v=9b1e")?.sha256).toBe(sha256("binary"));
  });

  it("makes the shell of the entry, what it preloads and the wasm runtime; the rest is cached on first use", async () => {
    const { byUrl } = await written(site());

    for (const url of [
      "/index.html",
      "/assets/index-aa.js",
      "/assets/vendor-bb.js",
      "/assets/index-cc.css",
      "/assets/core_bg-ee.wasm",
      "/flare-core-wasm/flare_im_core_sdk.js?v=9b1e",
      "/flare-core-wasm/flare_im_core_sdk_bg.wasm?v=9b1e",
      "/flare-core-wasm/snippets/crate-1/inline0.js",
    ]) {
      expect(byUrl.get(url)?.precache, url).toBe(true);
    }
    expect(byUrl.get("/assets/settings-dd.js")?.precache).toBeUndefined();
  });

  it("keeps a copy of every file a later deployment would overwrite", async () => {
    const outDir = site();
    const { byUrl } = await written(outDir);

    expect(byUrl.get("/index.html")?.source).toBe("/builds/20261105-abc/index.html");
    expect(byUrl.get("/flare-core-wasm/flare_im_core_sdk.js?v=9b1e")?.source)
      .toBe("/builds/20261105-abc/flare-core-wasm/flare_im_core_sdk.js");
    expect(byUrl.get("/assets/index-aa.js")?.source).toBeUndefined();
    expect(fs.readFileSync(path.join(outDir, "builds/20261105-abc/index.html"), "utf8")).toBe(INDEX);
    expect(fs.readFileSync(path.join(outDir, "builds/20261105-abc/flare-core-wasm/flare_im_core_sdk.js"), "utf8")).toBe("glue");
  });

  it("keeps the manifest itself beside the copies, for the release manifest to point at", async () => {
    const outDir = site();
    const { text } = await written(outDir);

    expect(fs.readFileSync(path.join(outDir, "builds/20261105-abc/asset-manifest.json"), "utf8")).toBe(text);
  });

  it("leaves source maps, art and everything else out", async () => {
    const { manifest } = await written(site());

    const urls = manifest.assets.map((asset) => asset.url);
    expect(urls).not.toContain("/assets/settings-dd.js.map");
    expect(urls.some((url) => url.includes("flare-im-ui-assets"))).toBe(false);
  });

  it("follows the deploy base", async () => {
    const outDir = output({ "index.html": `<script src="/app/assets/index-aa.js"></script>`, "assets/index-aa.js": "entry" });
    const { byUrl } = await written(outDir, "/app/");

    expect(byUrl.get("/app/index.html")?.source).toBe("/app/builds/20261105-abc/index.html");
    expect(byUrl.get("/app/assets/index-aa.js")?.precache).toBe(true);
  });
});

describe("resolveWebBuildId", () => {
  it("takes the id the release pipeline names", () => {
    expect(resolveWebBuildId({ VITE_FLARE_WEB_BUILD_ID: " 20261105-abc " })).toBe("20261105-abc");
  });

  it("makes one from the day otherwise, different each build", () => {
    const now = new Date("2026-11-05T08:00:00Z");
    const first = resolveWebBuildId({}, now);
    expect(first).toMatch(/^20261105-[0-9a-f]{8}$/);
    expect(resolveWebBuildId({}, now)).not.toBe(first);
  });

  it("refuses an id that cannot be a directory name", () => {
    expect(() => resolveWebBuildId({ VITE_FLARE_WEB_BUILD_ID: "../up" })).toThrow(/VITE_FLARE_WEB_BUILD_ID/);
  });
});

describe("flareWebUpdateBuild", () => {
  function plugin(outDir: string, viteBuild = vi.fn(async () => undefined)) {
    const built = flareWebUpdateBuild({ buildId: "b1", viteBuild, pinned: [] });
    built.configResolved({
      root: outDir,
      base: "/",
      mode: "production",
      resolve: { alias: [] },
      build: { outDir: ".", assetsDir: "assets" },
      logger: { info: () => undefined },
    });
    return { built, viteBuild };
  }

  it("runs on builds only, after every other plugin, and names the build to the page", () => {
    const { built } = plugin(site());

    expect(built.apply).toBe("build");
    expect(built.closeBundle).toMatchObject({ order: "post", sequential: true });
    expect(built.config()).toEqual({ define: { __FLARE_WEB_BUILD_ID__: JSON.stringify("b1") } });
  });

  it("bundles the worker into one classic script at the root and writes the manifest", async () => {
    const outDir = site();
    const { built, viteBuild } = plugin(outDir);

    built.writeBundle();
    await built.closeBundle.handler();

    const config = (viteBuild.mock.calls as unknown as Array<[{ configFile: boolean; build: { emptyOutDir: boolean; lib: { formats: string[]; fileName(): string; entry: string } } }]>)[0][0];
    expect(config.configFile).toBe(false);
    expect(config.build.emptyOutDir).toBe(false);
    expect(config.build.lib.formats).toEqual(["iife"]);
    expect(config.build.lib.fileName()).toBe("sw.js");
    expect(config.build.lib.entry).toBe(path.join(outDir, "src/sw.ts"));
    expect(fs.existsSync(path.join(outDir, "asset-manifest.json"))).toBe(true);
  });

  it("does nothing for a build that wrote nothing", async () => {
    const outDir = output({});
    const { built, viteBuild } = plugin(outDir);

    await built.closeBundle.handler();

    expect(viteBuild).not.toHaveBeenCalled();
  });
});
