# SDK Spec

`manifest.json` is the lightweight entry point for client SDK contracts.

Long-term, this directory should be a platform SDK overlay over
`../flare-core-sdk-engine/bindings/contract`, not a second declaration of the same
native contract. The core bindings contract owns L1/native operation ids, C/Tauri
routes, event ids, stable error codes, and Rust DTO JSON schemas. `sdk-spec`
should keep only the L3 platform API decisions that are not knowable from L1:
facade grouping, platform method names, SDK-facing request/response type aliases,
listener ergonomics, platform support metadata, docs, examples, and generated
package layout.

The actual contract is split by responsibility:

```text
manifest.json                    workspace metadata and include list
platforms/targets.json           platform matrix
shared/errors.json               shared error shape and stable codes
shared/events.json               shared event names
shared/listeners.json            listener callback contracts
shared/message_build_catalog.json  canonical message build ops (sync from L1)
native/c_abi.json                C ABI runtime dispatch metadata for platform bridges
modules/*.json                   one SDK module per file
models/*.json                    typed DTOs (interface/class per language)
golden/                          request/response/event contract examples
```

Today it still owns:

- canonical module and method names
- request and response type names
- event names
- stable error codes
- platform support status
- C ABI mapping
- native request/response encoding, callback and handle policy metadata
- generated docs and platform constants

The spec does not own IM behavior. Behavior belongs in `../flare-core-sdk-engine`.

Target ownership:

| Concern | Source |
|---------|--------|
| Native API ids, C symbols, Tauri commands, direct invoke routes | `../flare-core-sdk-engine/bindings/contract/*.json` |
| Native event ids and error codes | `../flare-core-sdk-engine/bindings/contract/events.json` and `errors.json` |
| Rust DTO wire schemas | `../flare-core-sdk-engine/bindings/contract/generated/model_schemas/*.schema.json` |
| Platform facade names and method names | `sdk-spec/modules/*.json` overlay |
| Platform DTO aliases and DTOs not exported by core schemas yet | `sdk-spec/models/*.json` overlay |
| Message build catalog presentation | derived from L1 `apis.json#message_builder`, with SDK display metadata overlay |

The migration path is to make `cargo xtask` build an expanded in-memory spec from
`bindings/contract` plus this overlay. Generated package code should consume that
expanded spec directly. Files under `sdk-spec` should shrink over time as more
contract data becomes derivable from L1.

## Layout rules

| Package | Contents |
|---------|----------|
| `api/` | Module facades + `FlareImClient` only (`session`, `messages`, **`messageBuilder`**, …) |
| `model/` | Generated DTOs: `Message`, `Conversation`, `BuildTextMessageRequest`, content payloads |
| `listener/` | Event listener contracts |
| `callback/` | Callback type aliases and completion contracts |
| `contract/` | SDK constants, bridge contracts, and shared generated contract exports |
| `adapter/` / `runtime/` | Platform runtime boundary; no business DTO ownership |

**Do not** define business DTOs or message-build shapes in adapters (e.g. `adapters/web/coreProtocol.ts`).  
Adapters may encode/decode wire bytes, but inputs/outputs must use **generated models** from `sdk-spec/models/`.

## Message builder module

- Module: `modules/message_builder.json` → `client.messageBuilder`
- Catalog: `shared/message_build_catalog.json` (one row per `create_*` op)
- Typed requests: `models/message_builder.json`
- Content payloads: `models/message_content_elems.json`

Apps should call:

```typescript
const catalog = await client.messageBuilder.listSupportedBuildOperations();
const draft = await client.messageBuilder.buildText({ conversationId, text: 'hi' });
await client.messages.sendMessage({ message: draft });
```

## Native binding metadata

`native/c_abi.json` currently lifts C boundary semantics from `../flare-core-sdk-engine/bindings/c` into the SDK spec:

- `transport` kind (`ffi-symbol`, `dispatch-json`, `message-dispatch-json`, `capability-dispatch-json`, `catalog-static`)
- request/response encoding (`typed-ffi`, `json`, `unit`, `handle`, `subscription`, ...)
- return mode (`sync`, `callback`, `callback-unit`, `event-stream`, `local`)
- callback type and handle ownership policy

Generated `NativeCallDescriptor` files in TypeScript, Flutter, Android, Apple, ArkTS, and Cangjie include this metadata. Platform bridges should prefer these descriptor fields over hard-coded operation-name sets.

`xtask` is now the SDK codegen entrypoint. This metadata should continue moving
toward derivation from `bindings/contract/apis.json`, `dispatch.json`,
`direct_invoke.json`, and `c_typed_abi.json` wherever possible. Keep explicit SDK
metadata only for platform-facing choices that the L1 contract intentionally does
not own.

## Contract tests

`golden/` holds the request / response / event examples every platform package
must encode, decode and map identically. The tests that consume them live next
to each package, not in a shared directory:

| Package | Tests |
|---------|-------|
| `packages/flare-core-typescript-sdk` | `test/wire_codec_contract.test.ts`, `test/events_api_contract.test.ts`, `test/capabilities_api_contract.test.ts` |
| `packages/flare-core-flutter-sdk` | `test/wire_codec_message_test.dart`, `test/default_flare_im_client_direct_ffi_test.dart` |

Adding a golden file without a consumer on every platform that has a runtime
adapter is a contract gap; add the test in the same change.

## Commands

```bash
# Sync message build catalog from flare-im-core-sdk L1 contract
make sync-spec

# Emit the Rust-owned expanded SDK contract snapshot
make expanded-spec

# Emit Rust-owned SDK docs and package READMEs
make docs

# Emit Rust-owned TypeScript model/listener/callback contracts
make typescript-contract

# Emit Rust-owned Dart/Kotlin/Swift/ArkTS/Cangjie model/listener/callback contracts
make platform-contract

# Emit Rust-owned platform adapter static artifacts
make platform-adapter

# Validate spec + regenerate all platform packages
make all

# Or step by step:
make spec
make codegen
```

## Change rule

1. Update `../flare-core-sdk-engine/bindings/contract` first when the native operation, event, error, or Rust DTO shape changes.
2. Update **`sdk-spec`** only for platform facade names, ergonomic method names, DTO aliases not yet derivable from core schemas, listener ergonomics, docs, or platform support metadata.
3. Run `make sync-spec` when the change is already derivable from L1, then `make codegen`.
4. Adjust **runtime adapters** only to call the new typed APIs; never hand-edit `GENERATED` files.
5. Run platform checks (`npm run typecheck`, `dart analyze`, ...).
