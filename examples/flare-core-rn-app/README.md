# flare-core-rn-app

English · [中文](README.zh-CN.md)

The **React Native** IM application entry point for `@flare-im/sdk`, using React 19, React Native 0.86, and Ant Design React Native to implement a mobile conversation/message workbench.

## SDK

- Package: `packages/@flare-im/sdk`
- Adapter: `src/adapters/react-native`
- Native bridge: `globalThis.__FLARE_IM_CORE_NATIVE__` or the RN native module `FlareImCoreSdk.invoke`
- Core ABI: `flare-core-sdk-engine/bindings/c`

Launching the page does not implicitly create an SDK client; `FlareCoreSdk.createClient()` is only created when you tap "Initialize SDK Client", and without a native bridge it directly shows the bridge diagnostics.

## Tech stack

- `react@19.2.7`
- `react-native@0.86.0`
- `@ant-design/react-native@5.4.3`
- `react-native-gesture-handler@3.0.2`
- `react-native-reanimated@4.4.1`
- `react-native-worklets@0.9.1`
- `@react-native/babel-preset@0.86.0`
- `@react-native/metro-config@0.86.0`

## Directory structure

```text
src/
├── application/      # State orchestration, SDK event bridging
├── domain/           # Entities, value objects, repository interfaces
├── infrastructure/   # SDK adapters, mappers, local storage, media
├── interface/        # Routing/pages, theme, IM UI components
└── shared/           # Config, DI, theme tokens
assets/
android/              # RN 0.86 Android native project
ios/                  # RN 0.86 iOS native project
scripts/
tests/
```

See the full specification in [`examples/STRUCTURE.md`](../STRUCTURE.md).

## Capability list

- SDK client initialization and native bridge diagnostics
- Ant Design RN conversation list, search, filtering, pinning, unread, recent-message preview
- Mobile chat window, connection-status banner, pinned messages, message bubbles, read/sent/failed-retryable states
- Chat more-actions, conversation details, mark read/unread, pin, do-not-disturb, archive, clear, and delete entries
- Composer emoji, stickers, attachments, and rich-text entries; the input box shows real emoji characters directly instead of marker text
- SDK Lab: runtime status, diagnostic snapshots, protocol capabilities, event stream
- Metro/Babel/RN official type configuration

Reference implementations: `examples/flare-core-flutter-app`, `examples/flare-core-web-app`.

## Development

The current example already includes the React Native 0.86 iOS/Android native projects. `npm run ios` and `npm run android`
first check the native project structure and then hand off to the RN CLI, avoiding the unclear CLI null exception that occurs when the native projects are missing.

```bash
cd examples/flare-core-rn-app
npm install
npm run typecheck
npm run verify
bundle install --path vendor/bundle
cd ios && bundle exec pod install && cd ..
npm run start
npm run ios
npm run android
```

The native projects are currently responsible for launching the RN app and bundling the Ant Design icon fonts. To make "Initialize SDK Client" connect to real core capabilities,
you need to continue implementing the RN native module `FlareImCoreSdk.invoke` and link `flare-core-sdk-engine/bindings/c` within it.

Android local debugging builds only `arm64-v8a,x86_64` by default, covering the common Apple Silicon/modern-emulator and real-device paths; full-ABI
release verification can use `-PreactNativeArchitectures=armeabi-v7a,arm64-v8a,x86,x86_64` for coverage.

The package metadata of `@ant-design/icons-react-native` still uses the old `dependency.assets` field; `postinstall` patches the installed
third-party RN CLI configuration, the project-level `react-native.config.js` continues to declare the font assets, and the Android/iOS native projects also bundle the font files explicitly.
