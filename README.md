# Flare IM Core Client SDK

English · [Simplified Chinese](README.zh-CN.md)

## Integration Boundary

The open-source stack provides business-neutral messaging and pluggable authentication. Use the Core quickstart with a locally signed token or integrate your identity service through the Core authentication contract. Flare Social provides account and social features in a separate stack. See [Governance](.github/GOVERNANCE.md) for the boundary.


This workspace contains typed client SDK adapters for `flare-im-core-sdk`.

The Rust core remains the only place for IM behavior. This workspace owns platform API shape, generated contracts, native artifact placement, docs, examples and contract tests.

## Architecture

```text
App
  -> L3 typed platform facade
  -> L2 runtime adapter
  -> L1 C ABI: ../flare-core-sdk-engine/bindings/c
  -> L0 Rust core: ../flare-core-sdk-engine
```

## Directory Map

```text
sdk-spec/        split contract source of truth
native/          C ABI index and produced native artifacts
packages/        platform SDK packages
examples/        platform smoke apps
docs/            generated and hand-written SDK docs
```

## Commands

```bash
make help
make all
make check

cargo xtask verify
cargo xtask sync-spec
cargo xtask codegen
cargo xtask wire-boundary-check
```

Common `make` targets:

- `make codegen`: regenerate SDK contracts **and sync official/docs/sdk** (11, 17, client-platform-api.json).
- `make spec`: validate split spec invariants.
- `make verify`: validate spec, core-contract parity, and package structure.
- `make all`: sync spec, verify, regenerate packages, and verify structure.
- `make codegen-check`: verify generated SDK outputs are up to date.
- `make wire-boundary-check`: verify Rust-owned wire boundary artifacts.
- `make check`: run spec/codegen/structure plus TypeScript, Dart, Swift, and optional Cangjie checks.
- `make clean`: remove local package/tool build caches.

## Rules

- Update `sdk-spec/modules/*.json` before changing public SDK APIs.
- Never duplicate message, conversation, sync, delivery, auth, presence, media, call or plugin business rules in platform packages.
- Keep platform wrappers thin: validate input, call C ABI, map result, emit typed event or typed error.
- Generated files are disposable. Do not edit generated files by hand.

## Production Contracts

- Runtime behavior: `docs/runtime-contracts.md`
- Architecture review and next steps: `docs/architecture-review.md`

---

## Next Steps

| Goal | Start here |
| --- | --- |
| Start a Core messaging server | [Core quickstart](https://github.com/flare-im/flare-core-server/blob/main/docs/QUICKSTART.md) |
| Connect your own identity provider | [Core authentication and token issuance](https://github.com/flare-im/flare-core-server/blob/main/docs/AUTH-TOKEN-ISSUANCE.md) |
| Add business rules around messaging | [Core hook contract](https://github.com/flare-im/flare-core-server/blob/main/docs/HOOK-PLUGIN-CONTRACT.md) |
| Build an IM interface | [Flare UI](https://github.com/flare-im/flare-im-design) |
| Report a security issue | [Security policy](.github/SECURITY.md) |

## Identity and Social Features

The open-source Core provides messaging infrastructure. You can connect your own identity and business logic through the Core authentication and hook contracts. Flare Social is maintained separately and provides accounts, contacts, group management, and moments. See the [Core governance policy](https://github.com/flare-im/flare-core-server/blob/main/.github/GOVERNANCE.md) for the open-source boundary.

## Integration Examples

Use the [Core example apps](https://github.com/flare-im/flare-core-examples) for platform wiring. Changes to shared send, ordering, or sync behavior belong in the [Rust SDK engine](https://github.com/flare-im/flare-core-sdk-engine).
