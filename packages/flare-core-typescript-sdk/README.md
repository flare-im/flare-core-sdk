# @flare-im/sdk

English · [中文](README.zh-CN.md)

The TypeScript client SDK for Flare IM — a typed wrapper over the Rust core (`flare-im-core-sdk`).

All the real IM logic (connection, sync, storage, timeline) lives in the Rust
core; this package wires it onto the various JS runtimes and provides complete
TypeScript types.

## Install

```bash
npm install @flare-im/sdk
```

> **This package ships TypeScript sources, not compiled JavaScript.**
>
> Every entry point resolves to a `.ts` file, so **your bundler has to transpile it**.
> Most setups already do the right thing (Vite, Next.js with `transpilePackages`,
> Nuxt, Expo). Two cases need one line of config:
>
> - **Webpack**: `node_modules` is excluded from `ts-loader`/`babel-loader` by default —
>   add an include rule for `@flare-im/sdk`.
> - **Plain Node.js**: run it through a TS-aware loader (`tsx`, `ts-node`), or import it
>   from a bundled app rather than directly.
>
> Shipping sources is deliberate: the runtime entry points differ per platform and the
> types stay exact. If your toolchain cannot transpile dependencies, tell us in an issue —
> that is the signal we need to publish a build.

## Pick an entry point by runtime

Transport and storage capabilities differ per runtime, so the entry points are
split — import from the matching subpath:

| Runtime | Import path | Transport / storage |
|---|---|---|
| Browser / H5 | `@flare-im/sdk/web` | WebSocket (WASM) + IndexedDB |
| Tauri desktop | `@flare-im/sdk/tauri` | QUIC + SQLite |
| uni-app | `@flare-im/sdk/uni-app` | native core |
| React Native | `@flare-im/sdk/react-native` | native core |

```ts
import { FlareCoreSdk } from "@flare-im/sdk/uni-app";
```

Swap `/uni-app` for `/web` in the browser or `/tauri` for Tauri; the rest of
your code is unchanged.

> The Tauri entry point requires the peer dependency `@tauri-apps/api ^2.0.0`.

## Other subpaths

```ts
import { SdkOperations, SdkEvents } from "@flare-im/sdk/contract";
```

`api` / `listener` / `model` / `callback` / `contract` / `media` / `lifecycle`
export operations, event listeners, data models, callbacks, the protocol
contract, media, and lifecycle respectively.

## Keeping earlier web builds

A rollback or a staged rollout goes back to an older web build, so that build's
`builds/<buildId>/` and hashed files must outlive later deployments. A deployment
that replaces the site drops them. Between the build and the deployment, carry them
over from what is deployed now:

```bash
npx flare-web-retain-builds --previous /srv/site --out dist --keep 3
```

`--keep` counts earlier builds and defaults to 3; the build in `--out` is not one of
them. `--out` defaults to `dist`. The order is kept in `builds/history.json`, which
has to deploy with the rest. A build that lost a file is dropped, with a warning, and
the next older one takes its place. A first deployment passes `--first-deployment` instead of `--previous`;
a `--previous` that does not exist is an error, so a wrong path cannot drop the earlier builds.

## A complete, runnable example

This package is the SDK layer; running it needs the matching runtime bridge and
a server. For complete, runnable apps see [`flare-core-examples`](https://github.com/flare-im/flare-core-examples) in the
repository — `flare-core-uni-app` is the most fully wired one.

For how to start the server, see `QUICKSTART.md` in the flare-im-core repository
(up and running in five minutes, no self-built user system required).

## For contributors

**Do not add IM business logic here.** Behavior belongs in `flare-im-core-sdk`
(Rust), exposed through `bindings/c`, then reflected in `sdk-spec/manifest.json`.
This package only does typed forwarding — pushing logic down into the core is
what lets all seven platforms share one implementation.

- Contract status: `contract-synced`
- Async model: Promise + event subscription
- FFI contract: `flare-im-ffi/v1`

## License

Apache-2.0
