# Native Boundary

The only native boundary is:

```text
../flare-core-sdk-engine/bindings/c
```

This workspace does not maintain a second native implementation.

## Contents

```text
abi/        copied or generated headers for platform package builds
artifacts/  produced .so/.a/.dylib/.xcframework files
```

Native artifacts are build outputs. Keep them out of source control unless a release process explicitly requires checked-in binaries.

## Sync prepared artifacts

Build artifacts in `flare-core-sdk-engine/dist` first, then run `make sync` from the SDK repository. `make sync-android` updates both the SDK's actual `native/artifacts/android/<abi>` link path and all app/package `jniLibs` consumers. `make sync-host` updates `native/artifacts/host`; the iOS and Flutter sync targets include it too. A local test build may set `CORE_DIST=/absolute/path/to/test-dist` without overwriting the engine's release dist.

Run `node --test scripts/native-artifact-sync.test.mjs` to verify distribution. The Flutter macOS app validates the host dylib against this SDK's generated C header before embedding it, so an old library fails during the build instead of crashing during SDK initialization. Rebuild and sync native artifacts after a C ABI change; a successful Swift compile alone cannot validate dynamically resolved symbols.
