import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

const packageRoot = process.cwd();
const srcRoot = path.join(packageRoot, "src");

/** Every module specifier a TypeScript source imports or re-exports, static or dynamic. */
function specifiers(source: string): string[] {
  const out: string[] = [];
  const patterns = [
    /\bimport\s+(?:type\s+)?(?:[^'";]*?\s+from\s+)?["']([^"']+)["']/g,
    /\bexport\s+(?:type\s+)?(?:\*|\{[^}]*\})\s+from\s+["']([^"']+)["']/g,
    /\bimport\(\s*["']([^"']+)["']\s*\)/g,
  ];
  for (const pattern of patterns) {
    for (const match of source.matchAll(pattern)) out.push(match[1]!);
  }
  return out;
}

function resolveRelative(from: string, specifier: string): string {
  const base = path.resolve(path.dirname(from), specifier);
  for (const candidate of [base, `${base}.ts`, path.join(base, "index.ts")]) {
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return candidate;
  }
  throw new Error(`cannot resolve ${specifier} from ${from}`);
}

/** The files `entry` pulls in, transitively, and every bare package it names. */
function importClosure(entry: string): { files: string[]; packages: string[] } {
  const files = new Set<string>();
  const packages = new Set<string>();
  const pending = [entry];
  while (pending.length > 0) {
    const file = pending.pop()!;
    if (files.has(file)) continue;
    files.add(file);
    for (const specifier of specifiers(fs.readFileSync(file, "utf8"))) {
      if (specifier.startsWith(".")) pending.push(resolveRelative(file, specifier));
      else packages.add(specifier);
    }
  }
  return {
    files: [...files].map((file) => path.relative(srcRoot, file)).sort(),
    packages: [...packages].sort(),
  };
}

describe("@flare-im/sdk/lifecycle subpath", () => {
  it("is exported from the package", () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf8")) as {
      exports: Record<string, unknown>;
    };
    expect(manifest.exports["./lifecycle"]).toBe("./src/lifecycle/index.ts");
  });

  it("pulls in neither the wasm runtime nor any bridge", () => {
    const { files, packages } = importClosure(path.join(srcRoot, "lifecycle/index.ts"));

    // Only the lifecycle module itself and plain generated models.
    expect(files.filter((file) => !file.startsWith("lifecycle/") && !file.startsWith("model/"))).toEqual([]);
    expect(files).toContain("lifecycle/platformLifecycle.ts");
    expect(files).toContain("lifecycle/appInfo.ts");
    // No third-party runtime either (protobufjs, @tauri-apps/*, the wasm pkg).
    expect(packages).toEqual([]);
  });

  it("exposes the lifecycle and the app identity helpers", async () => {
    const lifecycle = await import("../src/lifecycle");
    expect(typeof lifecycle.PlatformLifecycle).toBe("function");
    expect(typeof lifecycle.withWebAppInfo).toBe("function");
    expect(typeof lifecycle.webAppInfoFromBuild).toBe("function");
  });
});
