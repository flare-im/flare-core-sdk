# Flare Core demos

Clone or download a demo, then follow its README to install dependencies, configure your Core endpoints, and start the app.

| Platform | Standalone repository |
| --- | --- |
| Android | [flare-core-android-demo](https://github.com/flare-im/flare-core-android-demo) |
| Electron | [flare-core-electron-demo](https://github.com/flare-im/flare-core-electron-demo) |
| Flutter | [flare-core-flutter-demo](https://github.com/flare-im/flare-core-flutter-demo) |
| iOS | [flare-core-ios-demo](https://github.com/flare-im/flare-core-ios-demo) |
| Tauri | [flare-core-tauri-demo](https://github.com/flare-im/flare-core-tauri-demo) |
| Web | [flare-core-web-demo](https://github.com/flare-im/flare-core-web-demo) |

Use your own Core server and tenant credentials. The application demonstrates the public SDK configuration, sign-in, conversations, messages, attachments, and endpoint replacement.

`bash examples/bootstrap-external-apps.sh web tauri` clones selected demos next to this SDK checkout. Omit platform names to clone all six, or set `FLARE_DEMO_DIR` to choose a download directory.

This directory also contains the [minimal TypeScript consumer](minimal/) and the [multi-device conformance manifest](multidevice_conformance.json).
