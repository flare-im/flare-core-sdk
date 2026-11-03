# Wire Naming Boundary

Flare IM enforces one canonical SDK JSON shape across native bindings and client SDK public APIs.

## Rules

| Layer | JSON key style | Responsibility |
| --- | --- | --- |
| `flare-core-sdk-engine/bindings/**` | **camelCase SDK JSON** | Wire truth generated from Rust DTO schemas and binding contracts |
| `flare-core-sdk/packages/**` (App/public API) | **camelCase** | Platform-idiomatic typed models without compatibility aliases |

## Bridge boundary

No generic snake/camel conversion is performed. Platform adapters encode typed
models into the same camelCase keys consumed by `flare-core-sdk-engine/bindings/**`,
and decode bridge responses as camelCase.

```
App camelCase → wireEncodeRequest → bindings camelCase
bindings camelCase → wireDecodeResponse → App camelCase
```

Typed `*ToMap` helpers emit explicit `wireName` fields for model payloads.
Generic map requests still pass through `wireEncodeRequest` /
`wireDecodeResponse`, but these helpers must not rename or dual-read fields.

Adapter `*FromJson` helpers read **camelCase keys only** (post-decode).

Event names, operation ids, enum values, and JWT claims may still use their
own documented string formats. That does not create alternate JSON field names.

## Forbidden patterns

- Dual-read fallbacks (`user_id` / `userId`, `store_config` / `storeConfig`)
- `field(json, 'snake', 'camel')` or multi-key `stringField` helpers
- Converting naming in both bridge and `fromJson`
- Sending SDK init fields that core does not define in `SdkConfigOverlay`

## Codegen

Shared wire boundary templates are Rust-owned in `flare-core-sdk-engine/xtask/src/main.rs`. Regenerate through Rust tooling:

```bash
cargo xtask codegen
```

Use `cargo xtask wire-boundary-check` to verify only the Rust-owned boundary artifacts. TypeScript is the reference implementation (`wireCodec.ts` + bridge encode/decode).
