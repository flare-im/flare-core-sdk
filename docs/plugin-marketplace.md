# Plugin Marketplace

Flare SDK plugins are cataloged and generated from typed manifests. The current
production contract is composition-time distribution: an application includes a
plugin package at build time, and runtime calls go through the core capability
registry.

Runtime download/install is intentionally not part of the current contract. The
catalog records this explicitly with `runtimeInstall = "not-supported"` so hosts
do not build hidden compatibility paths.
The verifier rejects any catalog entry whose `distribution` is not exactly
`composition-time` or whose `runtimeInstall` is not exactly `not-supported`.

## Catalog Contract

The composition-time SDK catalog lives at:

```text
../flare-plugins-commercial/sdk/catalog/plugins.json
```

The public discovery catalog is maintained in [flare-plugin-catalog](https://github.com/flare-im/flare-plugin-catalog).

Each composition-time catalog entry must match its `plugin.json` manifest:

- `id`
- `version`
- `displayName`
- `manifestPath`
- `manifestSha256`
- `sourcePath`
- `category`
- `platforms`
- `distribution`
- `runtimeInstall`

`manifestSha256` is calculated from the exact manifest bytes referenced by
`manifestPath`. This is the current build-time supply-chain integrity boundary:
the catalog cannot point at a plugin manifest that has drifted. Runtime package
download, signature verification, sandboxing, and permission consent remain
unsupported until those contracts are implemented end to end.

`sourcePath` must be the directory that owns `manifestPath`, and `category` must
match the manifest's primary namespace. The catalog does not get a second place
to redefine package ownership.

Plugin events must use typed declaration objects with an `id` and JSON
`schema`. String-only event ids are rejected by manifest verification.
Plugin permissions must also use typed declaration objects with `id` and
non-empty `description`; string-only permission ids are rejected.

Validate it with:

```bash
cargo xtask plugin-verify
```

## Generated Platform APIs

Run:

```bash
cargo xtask plugin-codegen
```

The generator emits platform stubs under `../flare-plugins-commercial/sdk/generated`. Each
stub delegates to the generated SDK capability API:

```ts
await client.capabilities.dispatchCapability({
  capabilityId: "flare.call.start",
  payload,
  conversationId,
  tenantId,
  userId,
})
```

Plugin-specific packages may provide UI and media implementation, but capability
ownership, namespace routing, enable/disable state, and operation checks stay in
core.

Current composition-time plugin manifests:

- `sdk.plugin.call` owns the `flare.call` namespace: the client side of the
  managed call plugin, whose operations dispatch to the approved runtime
  service. Its realtime packets reach apps as the typed `pluginRealtime` event.
- `sdk.plugin.ai` owns the `ai` namespace for local AI capability dispatch:
  semantic search, message translation, and reply suggestions.

The AI manifest defines strict host/provider payload schemas:

- `search.semantic` accepts `query` and `limit`, and returns scored message
  snippets.
- `message.translate` accepts a `message_id` and `target_locale`, and returns
  translated text for the same message.
- `reply.suggest` accepts bounded `recent_message_ids` and
  `max_suggestions`, and returns bounded suggested reply strings.
- `ai.model.ready` and `ai.model.unavailable` are typed events. Ready events
  carry `model_id`, `provider`, and declared capabilities; unavailable events
  carry a finite reason enum plus `retryable`.

It only defines the typed capability boundary; model runtime, embedding index,
prompt policy, and privacy UX are supplied by the host plugin.

## Runtime Registry

`SdkCapabilityRegistry` owns runtime dispatch:

- `register` validates manifest identity and namespace ownership.
- `enable` / `disable` controls availability.
- `list_manifests` exposes registered plugin descriptors.
- `invoke` routes by capability namespace and rejects undeclared operations.

This keeps plugin behavior product-neutral and prevents example apps from
becoming a second plugin runtime.

## Verification

Run the lightweight gate:

```bash
cargo xtask plugin-marketplace
```

The gate is also part of `cargo xtask verify`. It checks catalog/schema presence,
manifest SHA-256 integrity, the call and AI plugin manifests, generated platform
stubs, core capability registry anchors, strict composition-time/runtime-install
catalog policy, and plugin codegen guardrails.
