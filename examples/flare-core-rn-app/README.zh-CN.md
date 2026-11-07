# flare-core-rn-app

[English](README.md) · 中文

`@flare-im/sdk` 的 **React Native** IM 应用入口，使用 React 19、React Native 0.86 与 Ant Design React Native 实现移动端会话/消息工作台。

## SDK

- Package: `packages/@flare-im/sdk`
- Adapter: `src/adapters/react-native`
- Native bridge: `globalThis.__FLARE_IM_CORE_NATIVE__` 或 RN native module `FlareImCoreSdk.invoke`
- Core ABI: `flare-core-sdk-engine/bindings/c`

页面启动不会隐式创建 SDK client；点击「初始化 SDK Client」时才会创建 `FlareCoreSdk.createClient()`，没有 native bridge 会直接显示 bridge 诊断。

## 技术栈

- `react@19.2.7`
- `react-native@0.86.0`
- `@ant-design/react-native@5.4.3`
- `react-native-gesture-handler@3.0.2`
- `react-native-reanimated@4.4.1`
- `react-native-worklets@0.9.1`
- `@react-native/babel-preset@0.86.0`
- `@react-native/metro-config@0.86.0`

## 目录结构

```text
src/
├── application/      # 状态编排、SDK 事件桥接
├── domain/           # 实体、值对象、仓储接口
├── infrastructure/   # SDK 适配器、mapper、本地存储、媒体
├── interface/        # 路由/页面、主题、IM UI 组件
└── shared/           # 配置、DI、主题 token
assets/
android/              # RN 0.86 Android 原生工程
ios/                  # RN 0.86 iOS 原生工程
scripts/
tests/
```

完整规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。

## 能力清单

- SDK client 初始化与 native bridge 诊断
- Ant Design RN 会话列表、搜索、筛选、置顶、未读、最近消息预览
- 移动聊天窗口、连接状态 banner、置顶消息、消息气泡、已读/发送/失败可重试态
- 聊天更多操作、会话详情、标记已读/未读、置顶、免打扰、归档、清空与删除入口
- Composer 表情、贴纸、附件、富文本入口；输入框直接展示真实表情字符，不展示标记文本
- SDK Lab：运行状态、诊断快照、协议能力、事件流
- Metro/Babel/RN 官方类型配置

参考实现：`examples/flare-core-flutter-app`、`examples/flare-core-web-app`。

## 开发

当前示例已包含 React Native 0.86 的 iOS/Android 原生工程。`npm run ios` 与 `npm run android`
会先检查原生工程结构，再交给 RN CLI 运行，避免缺少原生工程时出现不清晰的 CLI null 异常。

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

连到哪里由 SDK 的 `access` 配置决定，打包时固定，登录页没有服务器设置。`start`、`ios`、`android`、`bundle:*`
会先跑 `npm run sync:access-config`，把 `FLARE_ACCESS_JSON`（`access` 对象的 JSON）写进 `.generated/flare-access.json`
（见 `src/config/access.ts`）。不给时开发包连本机默认栈（`ws://127.0.0.1:60051`、核心 API `http://127.0.0.1:50050`；
Android 模拟器在 `FLARE_ACCESS_JSON` 里用 `10.0.2.2`，或用 `adb reverse`），发布包不提供登录。
第二个接入点写进 `developmentEndpoints.accessPoints`。

原生工程当前负责启动 RN app 和打包 Ant Design icon 字体。要让「初始化 SDK Client」连接真实核心能力，
需要继续实现 RN native module `FlareImCoreSdk.invoke`，并在其中链接 `flare-core-sdk-engine/bindings/c`。

Android 本机调试默认只构建 `arm64-v8a,x86_64`，覆盖常见 Apple Silicon/现代模拟器和真机路径；完整 ABI
发布验证可用 `-PreactNativeArchitectures=armeabi-v7a,arm64-v8a,x86,x86_64` 覆盖。

`@ant-design/icons-react-native` 当前包元数据仍使用旧的 `dependency.assets` 字段；`postinstall` 会修补安装后的
第三方 RN CLI 配置，项目级 `react-native.config.js` 继续声明字体资产，Android/iOS 原生工程也会显式打包字体文件。
