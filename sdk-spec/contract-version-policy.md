# Contract Version Policy

This policy defines how Flare client SDK contracts move together without hiding
breaking changes behind platform adapters.

## Version Sources

| Layer | Current source | Current value | Compatibility rule |
|-------|----------------|---------------|--------------------|
| Shared model proto | `../flare-protocol/Cargo.toml` | `2.1.0` | Breaking shared model/wire changes require a major version bump or a new `*.vN` proto package before public release. |
| gRPC service proto | `../flare-protocol-grpc/Cargo.toml` | `2.3.0` | Service surface changes are pre-1.0. Breaking request/response or service ownership changes require a minor bump while pre-1.0, and a major bump after 1.0. |
| Native FFI contract | `sdk-spec/manifest.json#ffiContractVersion`, `sdk-spec/native/c_abi.json#contract`, generated platform constants | `flare-im-ffi/v1` | Must be identical across the manifest, generated client spec, native C ABI metadata, and every generated platform package. Any incompatible C ABI, event code, operation id, callback shape, handle policy, or JSON dispatch encoding change requires `vN+1`. |
| Platform SDK API | `sdk-spec/manifest.json#apiVersion` | `1.0.0` | Semver for the platform SDK contract overlay. Additive modules/models/events are minor bumps before 1.0; breaking platform API or DTO shape changes are minor bumps while pre-1.0 and major bumps after 1.0. |
| Published package semver | Per package manifest when present | TypeScript `1.0.6`, Flutter `0.1.0` | Package versions may lag the spec while packages are private or unpublished, but must be valid semver and must not claim a newer major contract than `apiVersion`. Release notes must state the sdk-spec `apiVersion` and `ffiContractVersion` they implement. |

Android and Apple source packages currently do not publish independent semver in
their package manifests. Their generated `SdkContract` constants are the
authoritative compatibility signal until those packages are prepared for external
distribution.

## Bump Rules

- Bump `ffiContractVersion` when a platform adapter compiled against the old
  native contract could call the wrong C symbol, send an incompatible JSON shape,
  decode an event code incorrectly, or mishandle ownership/lifetime.
- Bump `apiVersion` when platform SDK consumers see a changed public API,
  request/response DTO shape, event/listener contract, stable error code, or
  generated module surface.
- Bump protocol crate versions when `flare-proto` or `flare-grpc-proto` changes
  wire compatibility, service ownership, or required fields. Proto package names
  already use `v1`; a future public breaking line should introduce `v2` packages
  instead of mutating `v1` in place.
- Never use `metadata` to smuggle a stable semantic change without updating the
  typed model/spec version that owns it.

## Release Gate

Before a client SDK release:

1. `sdk-spec/manifest.json#ffiContractVersion`,
   `sdk-spec/generated/client_spec.json#ffiContractVersion`,
   `sdk-spec/native/c_abi.json#contract`, and generated platform constants must
   match exactly.
2. `sdk-spec/manifest.json#apiVersion` and
   `sdk-spec/generated/client_spec.json#apiVersion` must match exactly.
3. Platform package versions that exist must be valid semver and must not claim
   a major version newer than `sdk-spec` `apiVersion`.
4. Release notes must list: `flare-proto` version, `flare-grpc-proto` version,
   `apiVersion`, `ffiContractVersion`, and supported platform package versions.
