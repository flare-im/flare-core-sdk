# Architecture Review

## Architectural Direction

`flare-im-core-client-sdk` should remain a contract-first multi-platform adapter workspace. It must not own IM business rules. Its job is to expose a stable, typed, low-cognitive-load API over `flare-core-sdk-engine/bindings/c`.

The current direction is sound:

- split spec files reduce manifest bloat;
- one model/listener per file keeps generated code readable;
- package names are aligned as `flare-core-*-sdk`;
- listener packages are now domain-oriented;
- `MessageSendCallback` gives app teams a direct progress/success/failure surface without parsing global events.

## Highest-Value Improvements

1. Promote remaining JSON-shaped DTOs to model groups.

   The biggest remaining maintainability cost is still `Map<String, Any?>` / `Record<string, Object>` in modules such as presence, media, diagnostics, and capability APIs. Keep the bridge JSON-friendly, but expose typed request/response models to app teams.

2. Implement thin runtime adapters per platform.

   Generated contracts are now ready. The next layer should be hand-written and small:

   - native loading;
   - handle ownership;
   - call invocation;
   - callback dispatch;
   - event demultiplexing;
   - error mapping;
   - lifecycle cleanup.

3. Add contract tests around events.

   The important tests are not UI tests. They should assert:

   - event envelope maps to typed listener;
   - `unsubscribe` is idempotent;
   - `dispose` cancels subscriptions;
   - `sendMessage` callback emits progress and exactly one terminal state when observable;
   - unknown events remain available through the raw envelope.

4. Introduce runtime diagnostics before release.

   Production IM SDKs need field debugging. Add diagnostics for:

   - SDK version;
   - FFI contract version;
   - native artifact load result;
   - connection state;
   - active subscription count;
   - dropped event count;
   - last error summary.

5. Keep capability/plugin APIs generic but typed at the boundary.

   `capabilities.dispatchCapability` is the right extension point. Avoid adding platform-specific plugin modules unless the core contract promotes them first.

## Boundary Rules

- Message ordering, delivery semantics, offline sync, multi-device rules, and conversation consistency stay in `flare-im-core-sdk`.
- Platform SDKs may cache local callback state and subscription ids, but must not implement message retry/business policies independently.
- Platform SDKs may adapt threading and native loading because those are platform responsibilities.
- Public stable fields belong in typed models, not `metadata`, `extra`, or `details`.

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| JSON-shaped DTOs leak into app code | Poor DX and runtime mistakes | Promote module DTOs into `sdk-spec/models/*.json` |
| Listener callbacks block native threads | Deadlocks and UI stalls | Enforce dispatch rules in runtime adapters |
| Event names drift across platforms | Hard-to-debug parity bugs | Keep `make verify` in the release gate |
| Generated contracts become runtime code | Business logic duplication | Keep generated code declarative; hand-write thin adapters only |
| Progress events flood UI | Jank and memory growth | Bound queues and coalesce progress updates |

## Next Implementation Order

1. Promote presence/media/diagnostics DTO models.
2. Build TypeScript runtime adapter first because it can act as the fastest contract executable.
3. Build Android/Flutter event demux next; they exercise coroutine/stream semantics.
4. Add Apple async/stream adapter.
5. Add ArkTS/Cangjie runtime bridge once native toolchains are available.
