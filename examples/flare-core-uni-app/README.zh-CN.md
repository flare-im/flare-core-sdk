# flare-core-uni-app

[English](README.md) · 中文

`@flare-im/sdk` 的 **uni-app** IM 工作台模板。

这个示例不再维护一套重复的 uni 专属 UI。uni-app 负责平台启动、页面入口、`src/router.ts` 路由注册和 SDK client factory；登录、首页同步、会话列表、聊天、消息构建、媒体、能力、诊断和 SDK Lab 功能面复用 `packages/@flare-im/vue-ui/app` 暴露的组件与业务函数，SDK 调用走 `packages/@flare-im/sdk` 的 `uni-app` adapter。

## SDK

- Package: `packages/@flare-im/sdk`
- Adapter: `src/adapters/uni-app`
- UI/workbench blocks: `packages/@flare-im/vue-ui/app`

## 传输与存储

uni-app adapter 按运行时自动分流(`src/main.ts` 的 `configureProductionAppClientFactory` +
`FlareCoreSdk.createClient()`):

| 运行时 | Bridge | 传输 | 存储 |
| --- | --- | --- | --- |
| **H5 / web** | WASM | WebSocket | IndexedDB |
| **App(Android / iOS)** | FFI(`bindings/c` TurboModule)→ 原生 core | WebSocket + QUIC 协议竞速 | SQLite |

- 没有传输选择器:原生运行时由核心按接入点在 QUIC 与 WebSocket 间竞速;H5 只有 WebSocket。
- 连到哪里由 SDK 的 `access` 配置(签名清单或开发模式端点)决定,不是登录页设置。
- App 端依赖原生插件把 `bindings/c` 暴露为 `globalThis.__FLARE_IM_CORE_NATIVE__`(TurboModule)。
- 竞速算法与 SQLite 引擎归 Rust core。详见
  [docs/design/transport-storage-multiruntime.md](../../docs/design/transport-storage-multiruntime.md)。
- 这个脚手架仍挂载已发布 `@flare-im/vue-ui` 1.0.9 的工作台(`@flare-im/vue-ui/app`),它早于接入配置,
  还没有接上新的连接链路。

## 目录结构

```text
App.vue                # 全局样式入口
src/main.ts            # uni-app createSSRApp + TS SDK uni adapter 配置
src/FlareCoreApp.vue   # uni 页面内挂载的 IM workbench 根组件
src/router.ts          # uni 侧路由表、route guard 和页面注册
src/platform/          # uni 平台媒体选择、本地路径解析与 Flutter 对齐能力清单
pages/index/index.vue  # 单一页面入口，挂载 uni 侧 workbench 根组件
tests/                 # uni-app / H5 / Flutter parity 约束
```

完整规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。

## 能力清单

- SDK 初始化、登录、登出与 token 更新
- 首页同步 gate、会话列表、会话打开、置顶、免打扰、归档、草稿、已读
- 聊天窗口、消息搜索、文本/表情/贴纸/富文本/媒体/结构化消息构建
- 消息编辑、删除、反应、引用、置顶、转发、重发与批量选择入口
- diagnostics、connection/session、media cache、presence、capability、events SDK Lab

功能面与 `examples/flare-core-flutter-app` 的工作台目标对齐；Vue/uni 侧通过 `packages/@flare-im/vue-ui/app` 复用组件、状态函数和平台 adapter hook，同时把应用壳与路由留在 uni 示例内，避免共享包变成固定应用。

## 开发

```bash
cd examples/flare-core-uni-app
npm install
npm run typecheck
npm run test
npm run verify
```
