# SDK verification assets

Complete applications and platform scaffolds are maintained only in the sibling
[`flare-core-examples`](https://github.com/flare-im/flare-core-examples) repository.
Its `apps/` directory contains Web, Tauri, Flutter, iOS, Android, Electron,
React Native, uni-app, ArkTS, and Cangjie. Application composition shared by
Vue consumers lives there in `shared/vue-reference`; SDK infrastructure stays in
this repository's `packages/`.

This directory retains a [minimal TypeScript consumer](minimal/README.md),
`multidevice_conformance.json`, the external-app manifest, and a checkout helper.
SDK package unit/contract tests remain beside the packages.

```bash
bash examples/bootstrap-external-apps.sh             # all ten app roots
bash examples/bootstrap-external-apps.sh web tauri   # validate a subset
```

The helper uses the local `dev` branch by default. CI may select its matching
branch with `BRANCH`. It never creates nested application checkouts inside the SDK.

Run the SDK ownership gates from this repository after checking out the examples:

```bash
node scripts/example-public-api-check.mjs
node scripts/real-sdk-example-assembly-check.mjs
node scripts/example-no-duplicate-ui.mjs
node scripts/reference-app-public-api-check.mjs
node scripts/reference-app-no-duplicate-ui-check.mjs
node scripts/reference-app-style-ownership-check.mjs
```

App build commands, platform maturity and composition conventions are documented
in `flare-core-examples/README.md` and `flare-core-examples/docs/STRUCTURE.md`.
