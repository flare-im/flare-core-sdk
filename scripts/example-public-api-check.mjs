import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const sourceRoots = [
  "examples/shared/vue-reference",
  "../flare-core-examples/apps/flare-core-web-app/src",
  "../flare-core-examples/apps/flare-core-tauri-app/src",
  "../flare-core-examples/apps/flare-core-flutter-app/lib",
  "../flare-core-examples/apps/flare-core-android-app/app/src/main",
  "../flare-core-examples/apps/flare-core-ios-app/Sources",
];
const sourceExtensions = new Set([".ts", ".vue", ".dart", ".kt", ".swift"]);
const forbidden = [
  /@flare-im\/vue-ui\/(?:src|internal|private)\//,
  /package:flare_im_ui\/src\//,
  /com\.flare\.im\.ui\.(?:internal|impl)\./,
  /flare-im-design\/packages\/(?:vue-im-ui|flutter-im-ui|android-im-ui|ios-im-ui)\/(?:src|lib\/src|Sources)\//,
];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (["build", "dist", ".build", ".dart_tool", "node_modules"].includes(entry.name)) continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(absolute);
    else if (sourceExtensions.has(path.extname(entry.name))) {
      const source = fs.readFileSync(absolute, "utf8");
      for (const pattern of forbidden) {
        if (pattern.test(source)) failures.push(`${path.relative(root, absolute)}: forbidden private UI import ${pattern}`);
      }
    }
  }
}

for (const relative of sourceRoots) walk(path.join(root, relative));

const web = JSON.parse(fs.readFileSync(path.join(root, "../flare-core-examples/apps/flare-core-web-app/package.json"), "utf8"));
const tauri = JSON.parse(fs.readFileSync(path.join(root, "../flare-core-examples/apps/flare-core-tauri-app/package.json"), "utf8"));
for (const [name, manifest] of [["web", web], ["tauri", tauri]]) {
  if (manifest.dependencies?.["@flare-im/vue-ui"] !== "file:../../../flare-im-design/packages/vue-im-ui") {
    failures.push(`${name}: @flare-im/vue-ui must use the latest workspace package`);
  }
  if (manifest.dependencies?.["@flare-im/tokens"] !== "file:../../../flare-im-design/tokens") {
    failures.push(`${name}: @flare-im/tokens must use the latest workspace package`);
  }
}

const flutter = fs.readFileSync(path.join(root, "../flare-core-examples/apps/flare-core-flutter-app/pubspec.yaml"), "utf8");
if (!/flare_im_ui:\s*\n\s+path: \.\.\/\.\.\/\.\.\/flare-im-design\/packages\/flutter-im-ui/.test(flutter)) {
  failures.push("flutter: flare_im_ui must use the latest workspace package");
}
const android = fs.readFileSync(path.join(root, "../flare-core-examples/apps/flare-core-android-app/app/build.gradle.kts"), "utf8");
if (!android.includes('com.flare.im:im-ui-compose:2.0.0-rc.1')) {
  failures.push("android: im-ui-compose must target 2.0.0-rc.1");
}
const ios = fs.readFileSync(path.join(root, "../flare-core-examples/apps/flare-core-ios-app/Package.swift"), "utf8");
if (!ios.includes('.package(path: "../../../flare-im-design/packages/ios-im-ui")')) {
  failures.push("ios: FlareIMUI must use the latest workspace package");
}

if (failures.length) {
  console.error(`example-public-api-check failed:\n${failures.map((item) => `- ${item}`).join("\n")}`);
  process.exit(1);
}

console.log("example-public-api-check passed");
