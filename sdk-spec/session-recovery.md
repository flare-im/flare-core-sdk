# Session recovery

The authoritative behavior is documented in
[`flare-core-sdk-engine/bindings/contract/session-recovery.md`](../../flare-core-sdk-engine/bindings/contract/session-recovery.md).

Platform adapters must preserve the core's local session identity across transport
disconnects. They must not silently replace a runtime on an invocation timeout,
override false session predicates using cached connection events, or replay writes
whose completion is unknown. Regenerate and ship WASM glue and binary together
with the TypeScript adapter: the runtime export `cancelPendingInvocations` enables
acknowledged cooperative recovery. An older binary without that export can only
wait for completion and report `wasm.recovery_pending`.

Applications should use connection state for network readiness and session state
for local API availability. A transport handshake (HTTP 101) is not evidence that
the current SDK instance has an authenticated session. Only explicit lifecycle
actions may dispose and recreate an instance.
