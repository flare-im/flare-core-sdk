#!/usr/bin/env bash
# Scaffold flare-core-{platform}-app directories (DDD layers aligned with flare-core-flutter-app).
# Does not overwrite flare-core-flutter-app or flare-core-web-app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ts_ddd_dirs=(
  "src/application/bridge"
  "src/application/providers"
  "src/application/bus"
  "src/application/outbound"
  "src/application/services"
  "src/application/selectors"
  "src/domain/entities"
  "src/domain/repositories"
  "src/domain/value_objects"
  "src/infrastructure/sdk"
  "src/infrastructure/repositories"
  "src/infrastructure/mappers"
  "src/infrastructure/media"
  "src/infrastructure/paths"
  "src/interface/navigation"
  "src/interface/screens"
  "src/interface/theme"
  "src/interface/components"
  "src/shared/config"
  "src/shared/theme"
  "assets/config"
  "assets/emoji"
  "assets/stickers"
  "scripts"
  "test"
)

kotlin_ddd_dirs=(
  "app/src/main/kotlin/com/flare/im/app"
  "app/src/main/kotlin/com/flare/im/application/bridge"
  "app/src/main/kotlin/com/flare/im/application/providers"
  "app/src/main/kotlin/com/flare/im/application/services"
  "app/src/main/kotlin/com/flare/im/domain/entities"
  "app/src/main/kotlin/com/flare/im/domain/repositories"
  "app/src/main/kotlin/com/flare/im/domain/value_objects"
  "app/src/main/kotlin/com/flare/im/infrastructure/sdk"
  "app/src/main/kotlin/com/flare/im/infrastructure/repositories"
  "app/src/main/kotlin/com/flare/im/infrastructure/mappers"
  "app/src/main/kotlin/com/flare/im/infrastructure/media"
  "app/src/main/kotlin/com/flare/im/interface/screens"
  "app/src/main/kotlin/com/flare/im/interface/theme"
  "app/src/main/kotlin/com/flare/im/interface/components"
  "app/src/main/kotlin/com/flare/im/shared/config"
  "app/src/main/kotlin/com/flare/im/shared/theme"
  "app/src/main/assets/config"
  "app/src/main/assets/emoji"
  "app/src/main/assets/stickers"
  "scripts"
  "app/src/test/kotlin/com/flare/im"
)

swift_ddd_dirs=(
  "Sources/FlareImApp/App"
  "Sources/FlareImApp/Application/Bridge"
  "Sources/FlareImApp/Application/Providers"
  "Sources/FlareImApp/Application/Services"
  "Sources/FlareImApp/Domain/Entities"
  "Sources/FlareImApp/Domain/Repositories"
  "Sources/FlareImApp/Domain/ValueObjects"
  "Sources/FlareImApp/Infrastructure/Sdk"
  "Sources/FlareImApp/Infrastructure/Repositories"
  "Sources/FlareImApp/Infrastructure/Mappers"
  "Sources/FlareImApp/Infrastructure/Media"
  "Sources/FlareImApp/Interface/Screens"
  "Sources/FlareImApp/Interface/Theme"
  "Sources/FlareImApp/Interface/Components"
  "Sources/FlareImApp/Shared/Config"
  "Sources/FlareImApp/Shared/Theme"
  "Resources/Config"
  "Resources/Emoji"
  "Resources/Stickers"
  "scripts"
  "Tests/FlareImAppTests"
)

arkts_ddd_dirs=(
  "entry/src/main/ets/app"
  "entry/src/main/ets/application/bridge"
  "entry/src/main/ets/application/providers"
  "entry/src/main/ets/application/services"
  "entry/src/main/ets/domain/entities"
  "entry/src/main/ets/domain/repositories"
  "entry/src/main/ets/domain/value_objects"
  "entry/src/main/ets/infrastructure/sdk"
  "entry/src/main/ets/infrastructure/repositories"
  "entry/src/main/ets/infrastructure/mappers"
  "entry/src/main/ets/infrastructure/media"
  "entry/src/main/ets/interface/screens"
  "entry/src/main/ets/interface/theme"
  "entry/src/main/ets/interface/components"
  "entry/src/main/ets/shared/config"
  "entry/src/main/ets/shared/theme"
  "entry/src/main/resources/rawfile/config"
  "entry/src/main/resources/rawfile/emoji"
  "entry/src/main/resources/rawfile/stickers"
  "scripts"
  "entry/src/ohosTest/ets/test"
)

cangjie_ddd_dirs=(
  "src/app"
  "src/application/bridge"
  "src/application/providers"
  "src/application/services"
  "src/domain/entities"
  "src/domain/repositories"
  "src/domain/value_objects"
  "src/infrastructure/sdk"
  "src/infrastructure/repositories"
  "src/infrastructure/mappers"
  "src/infrastructure/media"
  "src/interface/screens"
  "src/interface/theme"
  "src/interface/components"
  "src/shared/config"
  "src/shared/theme"
  "resources/config"
  "resources/emoji"
  "resources/stickers"
  "scripts"
  "test"
)

touch_gitkeep() {
  local dir="$1"
  mkdir -p "$dir"
  if [[ ! -f "$dir/.gitkeep" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    touch "$dir/.gitkeep"
  fi
}

scaffold_dirs() {
  local app_root="$1"
  shift
  local dirs=("$@")
  for d in "${dirs[@]}"; do
    touch_gitkeep "$app_root/$d"
  done
}

write_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" >"$path"
  fi
}

scaffold_ts_app() {
  local name="$1"
  local platform="$2"
  local adapter="$3"
  local app_root="$ROOT/$name"

  scaffold_dirs "$app_root" "${ts_ddd_dirs[@]}"

  write_if_missing "$app_root/.gitignore" "$(cat <<'EOF'
node_modules/
dist/
build/
.DS_Store
*.log
.env.local
EOF
)"

  write_if_missing "$app_root/package.json" "$(cat <<EOF
{
  "name": "$name",
  "private": true,
  "version": "0.1.0",
  "description": "Production-oriented IM app template for flare-core-typescript-sdk ($platform).",
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "flare-core-typescript-sdk": "file:../../packages/flare-core-typescript-sdk"
  },
  "devDependencies": {
    "typescript": "~5.6.2"
  }
}
EOF
)"

  write_if_missing "$app_root/tsconfig.json" "$(cat <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": {
      "@application/*": ["src/application/*"],
      "@domain/*": ["src/domain/*"],
      "@infrastructure/*": ["src/infrastructure/*"],
      "@interface/*": ["src/interface/*"],
      "@shared/*": ["src/shared/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.tsx"]
}
EOF
)"

  write_if_missing "$app_root/src/shared/config/app_defaults.json" "$(cat <<'EOF'
{
  "tenantId": "default",
  "platform": "web",
  "runtime": "wasm"
}
EOF
)"

  write_if_missing "$app_root/README.md" "$(cat <<EOF
# $name

\`flare-core-typescript-sdk\` 的 **$platform** 生产级 IM 应用模板，目录分层与 \`flare-core-flutter-app\` 对齐。

## SDK

- Package: \`packages/flare-core-typescript-sdk\`
- Adapter: \`src/adapters/$adapter\`

## 目录结构

\`\`\`text
src/
├── application/      # 状态编排、SDK 事件桥接
├── domain/           # 实体、值对象、仓储接口
├── infrastructure/   # SDK 适配器、mapper、本地存储、媒体
├── interface/        # 路由/页面、主题、IM UI 组件
└── shared/           # 配置、DI、主题 token
assets/
scripts/
test/
\`\`\`

完整规范见 [\`examples/STRUCTURE.md\`](../STRUCTURE.md)。

## 能力清单

- SDK 初始化、登录、登出
- 订阅连接/会话/消息/同步事件
- 会话列表、打开单聊、置顶、删除、草稿、已读、同步
- 文本与富媒体消息发送、撤回、编辑、反应
- diagnostics / media cache / presence / capability 入口
- 生命周期内正确 \`dispose\` SDK 资源

参考实现：\`examples/flare-core-flutter-app\`、\`examples/flare-core-web-app\`。

## 开发

\`\`\`bash
cd examples/$name
npm install
npm run typecheck
\`\`\`
EOF
)"
}

scaffold_rn_app() {
  scaffold_ts_app "flare-core-rn-app" "React Native" "react-native"
  local app_root="$ROOT/flare-core-rn-app"
  scaffold_dirs "$app_root" "android" "ios" "__tests__"
  write_if_missing "$app_root/index.js" "$(cat <<'EOF'
import { AppRegistry } from 'react-native';
import App from './src/interface/screens/App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
EOF
)"
  write_if_missing "$app_root/app.json" "$(cat <<'EOF'
{
  "name": "FlareCoreRnApp",
  "displayName": "Flare IM RN"
}
EOF
)"
  write_if_missing "$app_root/src/interface/screens/App.tsx" "$(cat <<'EOF'
import React from 'react';
import { SafeAreaView, Text } from 'react-native';

export default function App() {
  return (
    <SafeAreaView>
      <Text>flare-core-rn-app scaffold — wire flare-core-typescript-sdk react-native adapter here.</Text>
    </SafeAreaView>
  );
}
EOF
)"
}

scaffold_uni_app() {
  scaffold_ts_app "flare-core-uni-app" "uni-app" "uni-app"
  local app_root="$ROOT/flare-core-uni-app"
  scaffold_dirs "$app_root" "pages/login" "pages/conversations" "pages/chat" "pages/sdk-lab"
  write_if_missing "$app_root/manifest.json" "$(cat <<'EOF'
{
  "name": "Flare IM",
  "appid": "__UNI__FLARE_IM",
  "description": "flare-core-uni-app IM template",
  "versionName": "0.1.0",
  "versionCode": "100",
  "transformPx": false,
  "vueVersion": "3"
}
EOF
)"
  write_if_missing "$app_root/pages.json" "$(cat <<'EOF'
{
  "pages": [
    { "path": "pages/login/index", "style": { "navigationBarTitleText": "Login" } },
    { "path": "pages/conversations/index", "style": { "navigationBarTitleText": "Conversations" } },
    { "path": "pages/chat/index", "style": { "navigationBarTitleText": "Chat" } },
    { "path": "pages/sdk-lab/index", "style": { "navigationBarTitleText": "SDK Lab" } }
  ]
}
EOF
)"
  for page in login conversations chat sdk-lab; do
    write_if_missing "$app_root/pages/$page/index.vue" "$(cat <<EOF
<template>
  <view class="page">
    <text>flare-core-uni-app — $page scaffold</text>
  </view>
</template>

<script setup lang="ts">
</script>

<style scoped>
.page {
  padding: 24px;
}
</style>
EOF
)"
  done
}

scaffold_electron_app() {
  scaffold_ts_app "flare-core-electron-app" "Electron" "web"
  local app_root="$ROOT/flare-core-electron-app"
  scaffold_dirs "$app_root" "electron" "renderer"
  write_if_missing "$app_root/electron/main.ts" "$(cat <<'EOF'
// Electron main process — host renderer with flare-core-typescript-sdk web adapter.
export {};
EOF
)"
}

scaffold_tauri_app() {
  scaffold_ts_app "flare-core-tauri-app" "Tauri" "web"
  local app_root="$ROOT/flare-core-tauri-app"
  # Override dependency: Tauri apps use the TypeScript SDK Tauri adapter.
  write_if_missing "$app_root/package.json" "$(cat <<'EOF'
{
  "name": "flare-core-tauri-app",
  "private": true,
  "version": "0.1.0",
  "description": "Production-oriented IM app template for flare-core-typescript-sdk/tauri (Tauri desktop).",
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "flare-core-typescript-sdk": "file:../../packages/flare-core-typescript-sdk"
  },
  "devDependencies": {
    "typescript": "~5.6.2"
  }
}
EOF
)"
  scaffold_dirs "$app_root" "src-tauri/src" "src-tauri/capabilities"
  write_if_missing "$app_root/src-tauri/Cargo.toml" "$(cat <<'EOF'
[package]
name = "flare-core-tauri-app"
version = "0.1.0"
edition = "2021"

[dependencies]
tauri = { version = "2", features = [] }

[build-dependencies]
tauri-build = { version = "2", features = [] }
EOF
)"
}

scaffold_android_app() {
  local name="flare-core-android-app"
  local app_root="$ROOT/$name"
  scaffold_dirs "$app_root" "${kotlin_ddd_dirs[@]}"
  touch_gitkeep "$app_root/app/src/main/jniLibs"

  write_if_missing "$app_root/.gitignore" "$(cat <<'EOF'
/build/
/.gradle/
/local.properties
*.iml
.idea/
.DS_Store
app/src/main/jniLibs/
EOF
)"

  write_if_missing "$app_root/settings.gradle.kts" "$(cat <<'EOF'
rootProject.name = "flare-core-android-app"
include(":app")
EOF
)"

  write_if_missing "$app_root/build.gradle.kts" "$(cat <<'EOF'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}
EOF
)"

  write_if_missing "$app_root/app/build.gradle.kts" "$(cat <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.flare.im"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.flare.im"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // TODO: wire packages/flare-core-android-sdk once the Android library module is published.
}
EOF
)"

  write_if_missing "$app_root/app/src/main/AndroidManifest.xml" "$(cat <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="Flare IM"
        android:supportsRtl="true">
        <activity
            android:name=".app.MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF
)"

  write_if_missing "$app_root/app/src/main/kotlin/com/flare/im/app/MainActivity.kt" "$(cat <<'EOF'
package com.flare.im.app

import android.app.Activity
import android.os.Bundle

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Wire flare-core-android-sdk and interface layer here.
    }
}
EOF
)"

  write_if_missing "$app_root/README.md" "$(cat <<'EOF'
# flare-core-android-app

`flare-core-android-sdk` 的生产级 Android IM 应用模板，目录分层与 `flare-core-flutter-app` 对齐。

## 目录结构

```text
app/src/main/kotlin/com/flare/im/
├── app/              # Application / Activity 入口
├── application/      # 状态编排、SDK 事件桥接
├── domain/
├── infrastructure/   # SDK 适配器、仓储、mapper、媒体
├── interface/        # Compose 页面、主题、组件
└── shared/
assets/
scripts/
```

规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。参考实现：`flare-core-flutter-app`。
EOF
)"
}

scaffold_ios_app() {
  local name="flare-core-ios-app"
  local app_root="$ROOT/$name"
  scaffold_dirs "$app_root" "${swift_ddd_dirs[@]}"
  touch_gitkeep "$app_root/FFI"

  write_if_missing "$app_root/.gitignore" "$(cat <<'EOF'
.DS_Store
/build/
DerivedData/
*.xcuserstate
FFI/
EOF
)"

  write_if_missing "$app_root/Package.swift" "$(cat <<'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlareImApp",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FlareImApp", targets: ["FlareImApp"]),
    ],
    dependencies: [
        .package(path: "../../packages/flare-core-apple-sdk"),
    ],
    targets: [
        .target(
            name: "FlareImApp",
            dependencies: [
                .product(name: "FlareCoreAppleSDK", package: "flare-core-apple-sdk"),
            ],
            path: "Sources/FlareImApp"
        ),
        .testTarget(
            name: "FlareImAppTests",
            dependencies: ["FlareImApp"],
            path: "Tests/FlareImAppTests"
        ),
    ]
)
EOF
)"

  write_if_missing "$app_root/Sources/FlareImApp/App/FlareImApp.swift" "$(cat <<'EOF'
import SwiftUI

@main
public struct FlareImApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            Text("flare-core-ios-app scaffold — wire FlareCoreAppleSDK here.")
        }
    }
}
EOF
)"

  write_if_missing "$app_root/README.md" "$(cat <<'EOF'
# flare-core-ios-app

`flare-core-apple-sdk` 的生产级 iOS IM 应用模板，目录分层与 `flare-core-flutter-app` 对齐。

## 目录结构

```text
Sources/FlareImApp/
├── App/
├── Application/
├── Domain/
├── Infrastructure/
├── Interface/
└── Shared/
Resources/
FFI/                  # Rust FFI artifacts (gitignored, synced by scripts)
scripts/
Tests/
```

规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。参考实现：`flare-core-flutter-app`。
EOF
)"
}

scaffold_arkts_app() {
  local name="flare-core-arkts-app"
  local app_root="$ROOT/$name"
  scaffold_dirs "$app_root" "${arkts_ddd_dirs[@]}"

  write_if_missing "$app_root/.gitignore" "$(cat <<'EOF'
/build/
/.hvigor/
/node_modules/
oh_modules/
.DS_Store
EOF
)"

  write_if_missing "$app_root/AppScope/app.json5" "$(cat <<'EOF'
{
  "app": {
    "bundleName": "com.flare.im",
    "vendor": "flare",
    "versionCode": 1000000,
    "versionName": "0.1.0",
    "label": "$string:app_name"
  }
}
EOF
)"

  write_if_missing "$app_root/entry/src/main/module.json5" "$(cat <<'EOF'
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "flare-core-arkts-app entry module",
    "mainElement": "EntryAbility",
    "deviceTypes": ["phone", "tablet"],
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/app/EntryAbility.ets",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ]
  }
}
EOF
)"

  write_if_missing "$app_root/entry/src/main/ets/app/EntryAbility.ets" "$(cat <<'EOF'
import UIAbility from '@ohos.app.ability.UIAbility';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    // Wire flare-core-harmony-arkts-sdk here.
  }
}
EOF
)"

  write_if_missing "$app_root/README.md" "$(cat <<'EOF'
# flare-core-arkts-app

`flare-core-harmony-arkts-sdk` 的生产级 HarmonyOS ArkTS IM 应用模板，目录分层与 `flare-core-flutter-app` 对齐。

## 目录结构

```text
entry/src/main/ets/
├── app/
├── application/
├── domain/
├── infrastructure/
├── interface/
└── shared/
entry/src/main/resources/rawfile/
scripts/
```

规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。参考实现：`flare-core-flutter-app`。
EOF
)"
}

scaffold_cangjie_app() {
  local name="flare-core-cangjie-app"
  local app_root="$ROOT/$name"
  scaffold_dirs "$app_root" "${cangjie_ddd_dirs[@]}"

  write_if_missing "$app_root/.gitignore" "$(cat <<'EOF'
/build/
/target/
.DS_Store
EOF
)"

  write_if_missing "$app_root/cjpm.toml" "$(cat <<'EOF'
[package]
name = "flare-core-cangjie-app"
version = "0.1.0"
description = "HarmonyOS Cangjie IM app template for flare-core-harmony-cangjie-sdk"
EOF
)"

  write_if_missing "$app_root/src/app/Main.cj" "$(cat <<'EOF'
// flare-core-cangjie-app entry — wire flare-core-harmony-cangjie-sdk here.
main(): Int64 {
    return 0
}
EOF
)"

  write_if_missing "$app_root/README.md" "$(cat <<'EOF'
# flare-core-cangjie-app

`flare-core-harmony-cangjie-sdk` 的生产级 HarmonyOS 仓颉 IM 应用模板，目录分层与 `flare-core-flutter-app` 对齐。

## 目录结构

```text
src/
├── app/
├── application/
├── domain/
├── infrastructure/
├── interface/
└── shared/
resources/
scripts/
test/
```

规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。参考实现：`flare-core-flutter-app`。
EOF
)"
}

remove_legacy_demos() {
  for legacy in android_demo harmony_demo ios_demo react_native_demo web_demo; do
    if [[ -d "$ROOT/$legacy" ]] && [[ -z "$(ls -A "$ROOT/$legacy" 2>/dev/null)" ]]; then
      rmdir "$ROOT/$legacy"
      echo "removed empty legacy directory: $legacy"
    fi
  done
}

main() {
  scaffold_rn_app
  scaffold_uni_app
  scaffold_electron_app
  scaffold_tauri_app
  scaffold_android_app
  scaffold_ios_app
  scaffold_arkts_app
  scaffold_cangjie_app
  remove_legacy_demos
  echo "platform example scaffolds ready under $ROOT"
}

main "$@"
