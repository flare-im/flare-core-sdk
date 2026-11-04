# SDK Reference Applications

These are the five official reference consumers of flare-im-design and the real
Flare SDK. Canonical UI migration is **incomplete**: the ownership model below is
the target, not a claim that all existing screens already meet it. See the
[Core reference apps](https://github.com/flare-im/flare-core-examples) for evidence and
remaining P1/P2 work.

SDK/session/data state belongs in each app; reusable navigation, workspaces,
conversations, messages, composer, overlays, tokens, responsive behavior and
accessibility belong in the design kit.

## Reference Apps

| App | Platform | UI package | SDK runtime |
| --- | --- | --- | --- |
| [Web](./flare-core-web-app) | Vue 3, browser | `@flare-im/vue-ui` | `@flare-im/sdk/web` + WASM |
| [Tauri](./flare-core-tauri-app) | Vue 3, Tauri 2 | `@flare-im/vue-ui` | `@flare-im/sdk/tauri` |
| [Flutter](./flare-core-flutter-app) | Flutter mobile/desktop | `flare_im_ui` | `flare_core_flutter_sdk` |
| [Android](./flare-core-android-app) | Kotlin, Jetpack Compose | `im-ui-compose` | `flare-core-android-sdk` |
| [iOS](./flare-core-ios-app) | SwiftUI | `FlareIMUI` | `flare-core-apple-sdk` |

All five focus on conversation and message SDK flows: Chats, message/conversation Search, message Media where supported, Settings, and SDK Lab. They intentionally do not expose a contact directory, group directory, or relationship graph. Group conversations may still appear in the conversation list because they are messaging targets, not directory features.

## Checkout

The five reference apps above are independent repositories (see
[EXTERNAL-APPS.json](./EXTERNAL-APPS.json)). They are not submodules; clone them
into place with `bash examples/bootstrap-external-apps.sh [web flutter ios android tauri]`.

## Shared Contracts

- Semantic tokens and six brand themes come from [Flare UI tokens](../../flare-im-design/tokens).
- App composition follows [Build an IM App](../../flare-im-design/website/app-kit/index.md).
- Public component coverage is listed in the [Component Catalog](../../flare-im-design/website/components/index.md).
- Supported extension boundaries are documented under [Customization](../../flare-im-design/website/customization/index.md).
- The reusable UI ownership rule is defined by the [UI component reuse policy](../../flare-im-design/docs/ui-component-reuse-policy.md).

Web and Tauri share `examples/shared/vue-reference`; this is a UI/SDK adapter, not a second component library. Native examples map SDK domain models into each package's public presentation contracts.

## Quality Gates

Run from `flare-im-core-client-sdk`:

```bash
node scripts/example-no-duplicate-ui.mjs
node scripts/example-public-api-check.mjs
node scripts/real-sdk-example-assembly-check.mjs
node scripts/check-reference-example-ui.mjs
node --test scripts/reference-app-checks.test.mjs
node scripts/reference-app-public-api-check.mjs
node scripts/reference-app-no-duplicate-ui-check.mjs
node scripts/reference-app-style-ownership-check.mjs
```

The aggregate check now includes all three new ownership gates and scans shared
composition as well as five app roots. Remaining violations fail the command;
there is no suppression baseline pretending that migration is finished.
Static checks are conservative heuristics, not a replacement for tracing actual
render paths and testing platform interactions.

## Other Scaffolds

React Native, ArkTS, Cangjie, uni-app, and Electron folders remain platform scaffolds. They are not part of this five-app UI migration and should not be treated as equivalent reference implementations.

See [STRUCTURE.md](./STRUCTURE.md) for application layering conventions.
