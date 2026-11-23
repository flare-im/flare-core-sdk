import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const sdkRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
test("sync distributes the same FFI into the SDK link path and every app consumer", () => {
  const root = mkdtempSync(join(tmpdir(), "flare-native-sync-"));
  try {
    const dist = join(root, "dist");
    const native = join(root, "native");
    const examples = join(root, "apps");
    const packages = join(root, "packages");
    const android = "libflare_im_core_sdk_ffi.so";
    const host = "libflare_im_core_sdk_ffi.dylib";
    for (const [path, bytes] of [[join(dist, "android/arm64-v8a", android), "current-android-ffi"], [join(dist, "host", host), "current-host-ffi"]]) {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, bytes);
    }
    for (const path of [join(native, "android/arm64-v8a", android), join(native, "host", host)]) {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, "stale-ffi");
    }
    const result = spawnSync("make", ["sync-android", "sync-flutter", `CORE_DIST=${dist}`, `NATIVE_ARTIFACTS_DIR=${native}`, `EXAMPLES_DIR=${examples}`, `PACKAGES_DIR=${packages}`, "ANDROID_ABIS=arm64-v8a"], { cwd: sdkRoot, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    for (const path of [join(native, "android/arm64-v8a", android), join(packages, "flare-core-android-sdk/src/main/jniLibs/arm64-v8a", android), join(examples, "flare-core-android-app/app/src/main/jniLibs/arm64-v8a", android), join(examples, "flare-core-flutter-app/android/app/src/main/jniLibs/arm64-v8a", android)]) {
      assert.equal(readFileSync(path, "utf8"), "current-android-ffi", path);
    }
    assert.equal(readFileSync(join(native, "host", host), "utf8"), "current-host-ffi");
    assert.equal(readFileSync(join(examples, "flare-core-flutter-app/macos/Runner", host), "utf8"), "current-host-ffi");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
