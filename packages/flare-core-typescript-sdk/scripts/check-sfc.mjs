#!/usr/bin/env node
// SFC compile-all gate.
//
// vue-tsc type-checks <script> blocks but does NOT compile the <template>
// or <style> blocks of every SFC — a template/style that fails to compile
// (bad v-slot syntax, malformed directive, broken scoped CSS) can slip past
// vue-tsc and only blow up at `vite build`, silently blanking a consumer that
// barrel-imports it. This gate compiles every `src/**/*.vue` in each example
// app through `@vue/compiler-sfc` (parse + compileScript + compileTemplate +
// compileStyle) and fails on the first real error.
//
// Usage:
//   node packages/flare-core-typescript-sdk/scripts/check-sfc.mjs            # all example apps
//   node packages/flare-core-typescript-sdk/scripts/check-sfc.mjs web tauri  # a subset (dir suffix)

import { readdirSync, statSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createRequire } from "node:module";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, "../../..");
const examplesDir = path.join(repoRoot, "examples");

const ALL_APPS = ["web", "tauri", "electron", "uni"];
const requested = process.argv.slice(2);
const apps = (requested.length ? requested : ALL_APPS).map((name) =>
  name.startsWith("flare-core-") ? name.replace(/^flare-core-|-app$/g, "") : name,
);

function findVueFiles(root) {
  const out = [];
  const walk = (dir) => {
    let entries;
    try {
      entries = readdirSync(dir);
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry === "node_modules" || entry === "dist" || entry === "dist-electron") continue;
      const full = path.join(dir, entry);
      const st = statSync(full);
      if (st.isDirectory()) walk(full);
      else if (entry.endsWith(".vue")) out.push(full);
    }
  };
  walk(root);
  return out.sort();
}

// Resolve one @vue/compiler-sfc that we can reuse for every app. Any app's
// copy validates SFC syntax fine (all apps pin vue ^3.5), so we take the first
// that resolves instead of requiring each app to install it.
async function loadCompilerSfc() {
  const candidates = [
    ...ALL_APPS.map((n) => path.join(examplesDir, `flare-core-${n}-app`) + path.sep),
    repoRoot + path.sep,
  ];
  for (const base of candidates) {
    try {
      const req = createRequire(base);
      const resolved = req.resolve("@vue/compiler-sfc");
      const mod = await import(pathToFileURL(resolved).href);
      return { sfc: mod.default ?? mod, from: resolved };
    } catch {
      // try next
    }
  }
  throw new Error(
    "Could not resolve @vue/compiler-sfc from any example app or the repo root. " +
      "Run `npm install` in ../flare-core-examples/apps/flare-core-web-app first.",
  );
}

function compileOne(sfc, filename, source) {
  const errors = [];
  const { descriptor, errors: parseErrors } = sfc.parse(source, { filename });
  for (const err of parseErrors ?? []) errors.push(`parse: ${err.message ?? err}`);
  if (errors.length) return errors;

  // Stable component id, mirrors what a bundler would derive.
  const id = Buffer.from(filename).toString("hex").slice(0, 8);
  const scoped = descriptor.styles.some((s) => s.scoped);

  if (descriptor.script || descriptor.scriptSetup) {
    try {
      sfc.compileScript(descriptor, { id });
    } catch (e) {
      errors.push(`script: ${e.message ?? e}`);
    }
  }

  if (descriptor.template) {
    const { errors: tErrors } = sfc.compileTemplate({
      source: descriptor.template.content,
      filename,
      id,
      scoped,
      slotted: descriptor.slotted,
      compilerOptions: {
        expressionPlugins: descriptor.template.lang === "ts" ? ["typescript"] : [],
      },
    });
    for (const err of tErrors ?? []) {
      errors.push(`template: ${typeof err === "string" ? err : err.message}`);
    }
  }

  for (const style of descriptor.styles) {
    const res = sfc.compileStyle({
      source: style.content,
      filename,
      id: `data-v-${id}`,
      scoped: style.scoped,
      preprocessLang: style.lang,
    });
    for (const err of res.errors ?? []) errors.push(`style: ${err.message ?? err}`);
  }

  return errors;
}

async function main() {
  const { sfc, from } = await loadCompilerSfc();
  console.log(`check:sfc — using @vue/compiler-sfc from ${path.relative(repoRoot, from)}`);

  let totalFiles = 0;
  let totalApps = 0;
  const failures = [];

  for (const app of apps) {
    const appDir = path.join(examplesDir, `flare-core-${app}-app`);
    const srcDir = path.join(appDir, "src");
    let files;
    try {
      files = findVueFiles(srcDir);
      if (app === "web" || app === "tauri") {
        files.push(...findVueFiles(path.join(examplesDir, "shared/vue-reference")));
      }
    } catch {
      console.warn(`  skip flare-core-${app}-app (no src/)`);
      continue;
    }
    if (!files.length) {
      console.warn(`  skip flare-core-${app}-app (no .vue files)`);
      continue;
    }
    totalApps += 1;
    let appFail = 0;
    for (const file of files) {
      totalFiles += 1;
      const source = readFileSync(file, "utf8");
      const errors = compileOne(sfc, file, source);
      if (errors.length) {
        appFail += 1;
        failures.push({ file: path.relative(repoRoot, file), errors });
      }
    }
    const rel = `flare-core-${app}-app`;
    console.log(`  ${appFail ? "FAIL" : "ok  "} ${rel}: ${files.length} .vue (${appFail} broken)`);
  }

  console.log(`\nCompiled ${totalFiles} SFC across ${totalApps} app(s).`);
  // 一个 app 都没扫到时不能悄悄算通过：那说明示例应用不在当前检出里
  // （web/tauri/flutter/ios/android 五个 app 目前被 .gitignore 排除），
  // 门禁实际什么也没查，必须让它在 CI 上显式可见。
  if (totalApps === 0) {
    console.warn("::warning::未找到任何示例应用，SFC 门禁本次未实际检查任何文件。");
    console.warn("检出中缺少 examples/*，请确认示例应用是否已纳入版本控制。");
  }
  if (failures.length) {
    console.error(`\n${failures.length} SFC failed to compile:\n`);
    for (const { file, errors } of failures) {
      console.error(`  ${file}`);
      for (const err of errors) console.error(`    - ${err}`);
    }
    process.exit(1);
  }
  console.log("All SFC compiled cleanly.");
}

main().catch((e) => {
  console.error(e.stack ?? String(e));
  process.exit(2);
});
