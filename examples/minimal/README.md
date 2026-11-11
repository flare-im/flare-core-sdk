# Minimal TypeScript consumer

`typescript-client.ts` creates the public Web SDK, reads its diagnostics and
releases it even when a call fails. It has no UI, product state or server settings.
Pass the host's WASM loader to `inspectWebSdk`; a full browser integration with
asset URLs, access configuration and messaging lives in `flare-core-examples`.

Run the small consumer against a deterministic WASM fixture, without native
artifacts or a server:

```bash
cd packages/flare-core-typescript-sdk
npm install
npm run smoke
```

The fixture verifies SDK adapter wiring and cleanup, not real transport delivery.
