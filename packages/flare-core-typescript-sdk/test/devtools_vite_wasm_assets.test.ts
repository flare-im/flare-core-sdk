import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { PassThrough } from "node:stream";
import { fileURLToPath } from "node:url";

import { afterEach, describe, expect, it } from "vitest";

// @ts-expect-error The helper is plain JS; its types live in src/devtools/vite.
import { createFlareCoreWebAppViteConfig } from "../devtools/vite/flareCoreWebAppVite.js";

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

type Middleware = (request: { url?: string }, response: FakeResponse, next: () => void) => void;
type Plugin = {
  name: string;
  configureServer?(server: { middlewares: { use(middleware: Middleware): void } }): void;
  writeBundle?(options: { dir?: string }): Promise<void>;
};
type Config = {
  plugins: Plugin[];
  define: Record<string, string>;
  resolve: { alias: Array<{ find: string | RegExp; replacement: string }> };
  server: { fs: { allow: string[] } };
};
type FakeResponse = PassThrough & { statusCode: number; headers: Record<string, string>; setHeader(name: string, value: string): void };

const temporaryDirs: string[] = [];

function temporaryDir(prefix: string) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  temporaryDirs.push(dir);
  return dir;
}

function writeFile(root: string, relativePath: string, contents: string) {
  const target = path.join(root, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, contents);
}

/** A wasm-bindgen output with snippets from two crates, the way the engine build lays it out. */
function fakeWasmPackage() {
  const root = temporaryDir("flare-wasm-pkg-");
  writeFile(root, "flare_im_core_sdk.js", "import './snippets/storage-1a2b/src/plugin_command.mjs';");
  writeFile(root, "flare_im_core_sdk_bg.wasm", "\0asm");
  writeFile(root, "README.md", "not served");
  writeFile(root, "snippets/storage-1a2b/src/plugin_command.mjs", "export const command = 1;");
  writeFile(root, "snippets/other-3c4d/inline0.js", "export const inline = 0;");
  return root;
}

function viteConfig(options: Record<string, unknown>): Config {
  const factory = createFlareCoreWebAppViteConfig({
    appDir: temporaryDir("flare-app-"),
    serverPort: 0,
    defineConfig: (configFactory: (context: { mode: string }) => Config) => configFactory,
    loadEnv: () => ({}),
    vuePlugin: () => ({ name: "vue" }),
    ...options,
  }) as (context: { mode: string }) => Config;
  return factory({ mode: "development" });
}

function wasmPlugin(config: Config) {
  const plugin = config.plugins.find((candidate) => candidate.name === "flare-wasm-binding-assets");
  if (!plugin) throw new Error("flare-wasm-binding-assets plugin missing");
  return plugin;
}

function devMiddleware(config: Config): Middleware {
  let middleware: Middleware | undefined;
  wasmPlugin(config).configureServer?.({ middlewares: { use: (handler) => { middleware = handler; } } });
  if (!middleware) throw new Error("no middleware installed");
  return middleware;
}

function request(middleware: Middleware, url: string) {
  const response = new PassThrough() as FakeResponse;
  response.statusCode = 200;
  response.headers = {};
  response.setHeader = (name, value) => { response.headers[name.toLowerCase()] = value; };
  const chunks: Buffer[] = [];
  response.on("data", (chunk: Buffer) => chunks.push(chunk));
  return new Promise<{ status: number; type?: string; body: string; passed: boolean }>((resolve) => {
    response.on("end", () => resolve({
      status: response.statusCode,
      type: response.headers["content-type"],
      body: Buffer.concat(chunks).toString("utf8"),
      passed: false,
    }));
    middleware({ url }, response, () => resolve({ status: 0, body: "", passed: true }));
  });
}

afterEach(() => {
  for (const dir of temporaryDirs.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
});

describe("flare-wasm-binding-assets", () => {
  it("serves the entry files and every snippet in development", async () => {
    const middleware = devMiddleware(viteConfig({ wasmBindingRoot: fakeWasmPackage() }));

    const glue = await request(middleware, "/flare-core-wasm/flare_im_core_sdk.js?v=abc");
    expect(glue).toMatchObject({ status: 200, type: "text/javascript; charset=utf-8" });
    const wasm = await request(middleware, "/flare-core-wasm/flare_im_core_sdk_bg.wasm");
    expect(wasm).toMatchObject({ status: 200, type: "application/wasm" });

    const snippet = await request(middleware, "/flare-core-wasm/snippets/storage-1a2b/src/plugin_command.mjs");
    expect(snippet).toEqual({
      status: 200,
      type: "text/javascript; charset=utf-8",
      body: "export const command = 1;",
      passed: false,
    });
    const other = await request(middleware, "/flare-core-wasm/snippets/other-3c4d/inline0.js");
    expect(other.body).toBe("export const inline = 0;");
  });

  it("refuses files outside the entry files and snippets", async () => {
    const middleware = devMiddleware(viteConfig({ wasmBindingRoot: fakeWasmPackage() }));

    expect((await request(middleware, "/flare-core-wasm/README.md")).status).toBe(404);
    expect((await request(middleware, "/flare-core-wasm/snippets/../README.md")).status).toBe(404);
    expect((await request(middleware, "/flare-core-wasm/snippets/%2e%2e/README.md")).status).toBe(404);
    expect((await request(middleware, "/flare-core-wasm/snippets/missing.mjs")).status).toBe(404);
    expect((await request(middleware, "/src/main.ts")).passed).toBe(true);
  });

  it("copies the entry files and the whole snippets tree into the build", async () => {
    const pkg = fakeWasmPackage();
    const outDir = temporaryDir("flare-dist-");
    writeFile(outDir, "flare-core-wasm/snippets/stale-0000/old.mjs", "stale");

    await wasmPlugin(viteConfig({ wasmBindingRoot: pkg })).writeBundle?.({ dir: outDir });

    const copied = (relativePath: string) => fs.readFileSync(path.join(outDir, "flare-core-wasm", relativePath), "utf8");
    expect(copied("flare_im_core_sdk.js")).toContain("plugin_command.mjs");
    expect(copied("flare_im_core_sdk_bg.wasm")).toBe("\0asm");
    expect(copied("snippets/storage-1a2b/src/plugin_command.mjs")).toBe("export const command = 1;");
    expect(copied("snippets/other-3c4d/inline0.js")).toBe("export const inline = 0;");
    expect(fs.existsSync(path.join(outDir, "flare-core-wasm/README.md"))).toBe(false);
    expect(fs.existsSync(path.join(outDir, "flare-core-wasm/snippets/stale-0000"))).toBe(false);
  });

  it("changes the build id when a snippet changes", () => {
    const pkg = fakeWasmPackage();
    const before = viteConfig({ wasmBindingRoot: pkg }).define["import.meta.env.VITE_FLARE_WASM_BUILD_ID"];
    writeFile(pkg, "snippets/storage-1a2b/src/plugin_command.mjs", "export const command = 2;");
    const after = viteConfig({ wasmBindingRoot: pkg }).define["import.meta.env.VITE_FLARE_WASM_BUILD_ID"];

    expect(JSON.parse(before)).toMatch(/^[0-9a-f]{12}$/);
    expect(after).not.toBe(before);
  });
});

describe("SDK and workspace resolution", () => {
  it("points the SDK aliases at this package wherever the app lives", () => {
    const config = viteConfig({});
    const alias = (find: string) => config.resolve.alias.find((entry) => entry.find === find)?.replacement;
    const sdkSources = path.join(fs.realpathSync(packageRoot), "src");

    expect(alias("@flare-im/sdk/web")).toBe(path.join(sdkSources, "adapters/web/index.ts"));
    expect(alias("@flare-im/sdk")).toBe(path.join(sdkSources, "index.ts"));
    expect(fs.existsSync(alias("@flare-im/sdk/web")!)).toBe(true);
  });

  it("finds the workspace from the SDK package and allows it to be overridden", () => {
    const workspace = fs.realpathSync(path.resolve(packageRoot, "../../.."));
    expect(viteConfig({}).server.fs.allow).toContain(workspace);

    const override = temporaryDir("flare-workspace-");
    expect(viteConfig({ workspaceRoot: override }).server.fs.allow).toContain(override);
  });
});
