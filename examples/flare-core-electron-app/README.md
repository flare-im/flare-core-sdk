# flare-core-electron-app

Electron desktop wrapper for the same Vue 3 workbench used by
`examples/flare-core-web-app`. The renderer owns its `src/App.vue` and
`src/router.ts`, while importing `@flare-im/vue-ui/app` building blocks so
login, conversations, chat, SDK Lab, media, diagnostics, theme, and i18n stay
aligned with the web example.

## Stack

- Renderer: Vue 3 + Vite + Naive UI + local app/router shell + `@flare-im/vue-ui/app` workbench blocks
- Route views: `src/views/*` owns Electron page composition and wraps shared workbench components
- SDK entry: `@flare-im/sdk` web client directly (WASM core), no app-level native module
- Desktop shell: Electron main/preload with context isolation and no renderer
  Node integration
- Production renderer hosting: local loopback static server for `dist/`
- Native desktop bridge: `window.flareNativeMediaActions.revealDownloadedFile`

## Transport & storage

This app uses the `@flare-im/sdk` **web client directly** (WASM core in the
renderer) — the same path as the web/H5 examples. **Transport is always WebSocket**: the
WASM build compiles QUIC out (`quinn` is `#[cfg(not(wasm32))]`) and a renderer cannot open
raw UDP, so QUIC is not available without running the native Rust core. For a QUIC + SQLite
desktop client, use the **Tauri** example (in-process Rust core).

**Storage differs by build target** (selected in `src/main.ts` from the Electron preload signal):

| Build | Transport | Storage |
| --- | --- | --- |
| Web build (`dev:web` / `preview:web`, no Electron) | WebSocket | IndexedDB |
| Packaged desktop app (Win/Mac, Electron shell) | WebSocket | **SQLite** (wa-sqlite + OPFS) |

The storage backend is the WASM core's injectable `setStorageHost`: web keeps the IndexedDB
host; desktop swaps in `sqliteOpfsStorageHost` (a real SQLite engine via wa-sqlite, persisted
to an OPFS file, running in a Web Worker). No native module, no napi-rs.

> The SQLite path needs the optional `wa-sqlite` dependency + Vite worker/WASM-asset config,
> and should be certified in a packaged Electron run (OPFS is unavailable in Node/SSR).
> See [docs/design/transport-storage-multiruntime.md](../../docs/design/transport-storage-multiruntime.md).

## Run

Build the WASM package first, the same as the web example:

```bash
cd flare-im-core-sdk
cargo xtask build wasm
```

Install and run the Electron app:

```bash
cd flare-core-sdk/examples/flare-core-electron-app
npm install
npm run dev
```

The example ships a local-development `.env` matching `flare-core-web-app`.
The app never holds a signing secret: with only a user id the SDK issues the
access token from the API gateway (`{httpUrl}/api/v1/auth/tokens`, start the
gateway with `FLARE_API_GATEWAY_AUTH_DEV_ISSUE=true` locally) and refreshes it
before expiry; or paste a backend-issued token in the login page.

Useful commands:

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start Vite renderer on `1433` and launch Electron |
| `npm run dev:web` | Run the same renderer in a browser |
| `npm run preview:web` | Preview the packaged web renderer |
| `npm run start:electron` | Build then launch Electron from `dist/` |
| `npm run typecheck` | Type-check renderer and Electron main/preload |
| `npm run build` | Build renderer and Electron main/preload |
| `npm run test` | Run shared SDK/architecture checks and Vitest |
| `npm run test:e2e` | Run the shared web workbench e2e suite against port `1433` |

## Package

Desktop packaging uses `electron-builder`. Run platform-specific targets on the
matching OS when possible:

```bash
npm run package:mac
npm run package:win
npm run package:linux
```

Local unpacked smoke package:

```bash
npm run package:dir
```

Artifacts are written to `release/`.

## Platform matrix

| Platform | Run | Package target |
|----------|-----|----------------|
| Web | `npm run dev:web`, `npm run preview:web` | `npm run build:web` |
| macOS | `npm run dev`, `npm run start:electron` | `npm run package:mac` (`dmg`, `zip`) |
| Windows | `npm run dev`, `npm run start:electron` | `npm run package:win` (`nsis`, `zip`) |
| Linux | `npm run dev`, `npm run start:electron` | `npm run package:linux` (`AppImage`, `deb`, `tar.gz`) |

## Runtime notes

- Dev mode loads `http://127.0.0.1:1433`.
- Packaged mode starts a loopback static server for `dist/` so absolute assets
  such as `/flare-core-wasm/*` and `/flare-im-ui-assets/*` resolve exactly as
  they do in the browser app.
- External navigations are opened by the OS browser.
- Renderer code remains browser-shaped. Add reusable SDK or UI behavior to
  `packages/@flare-im/vue-ui` or `packages/@flare-im/sdk`, not
  to the Electron shell.
