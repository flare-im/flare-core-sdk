# Flare Core Flutter SDK

This package is a typed adapter over `flare-core-sdk-engine/bindings/c`.

- Status: `contract-synced`
- Async model: Future + Stream
- FFI contract: `flare-im-ffi/v2`

Do not add IM business logic here. Add behavior to `flare-im-core-sdk`, expose it through `bindings/c`, then update `sdk-spec/manifest.json`.
