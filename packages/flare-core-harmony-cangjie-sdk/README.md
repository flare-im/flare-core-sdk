# Flare Core HarmonyOS Cangjie SDK

This package is a typed adapter over `flare-core-sdk-engine/bindings/c`.

- Status: `contract-synced`
- Async model: native async result
- FFI contract: `flare-im-ffi/v1`

Do not add IM business logic here. Add behavior to `flare-im-core-sdk`, expose it through `bindings/c`, then update `sdk-spec/manifest.json`.
