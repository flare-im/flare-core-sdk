# @flare-im/sdk

[English](README.md) · 中文

Flare IM 的 TypeScript 客户端 SDK —— 对 Rust 核心（`flare-im-core-sdk`）的类型化封装。

真正的 IM 逻辑（连接、同步、存储、时间线）全在 Rust 核心里；这个包负责把它接到
各个 JS 运行时上，并提供完整的 TypeScript 类型。

## 安装

```bash
npm install @flare-im/sdk
```

> **本包发布的是 TypeScript 源码，不是编译后的 JavaScript。**
>
> 每个入口都指向 `.ts` 文件，因此**需要你的打包器来编译它**。多数工具链默认就能处理
> （Vite、配了 `transpilePackages` 的 Next.js、Nuxt、Expo）。两种情况要加一行配置：
>
> - **Webpack**：`ts-loader` / `babel-loader` 默认排除 `node_modules`，需要为
>   `@flare-im/sdk` 加一条 include 规则。
> - **直接跑 Node.js**：用支持 TS 的加载器（`tsx`、`ts-node`），或者从打包后的应用里引用。
>
> 发源码是有意的：各平台的运行时入口不同，且类型能保持精确。如果你的工具链无法编译
> 依赖，请开 issue 告诉我们——那正是我们需要的、决定要不要发布构建产物的信号。

## 按运行时选择入口

不同运行时的传输与存储能力不同，所以入口是分开的 —— 直接从对应子路径导入：

| 运行时 | 导入路径 | 传输 / 存储 |
|---|---|---|
| 浏览器 / H5 | `@flare-im/sdk/web` | WebSocket（WASM）+ IndexedDB |
| Tauri 桌面 | `@flare-im/sdk/tauri` | QUIC + SQLite |
| uni-app | `@flare-im/sdk/uni-app` | 原生核心 |
| React Native | `@flare-im/sdk/react-native` | 原生核心 |

```ts
import { FlareCoreSdk } from "@flare-im/sdk/uni-app";
```

浏览器端换成 `/web`，Tauri 换成 `/tauri`，其余代码不变。

> Tauri 入口需要 peer 依赖 `@tauri-apps/api ^2.0.0`。

## 其它子路径

```ts
import { SdkOperations, SdkEvents } from "@flare-im/sdk/contract";
```

`api` / `listener` / `model` / `callback` / `contract` / `media` / `lifecycle`
分别导出操作、事件监听、数据模型、回调、协议契约、媒体与生命周期。

## 保留旧的 Web 版本

回滚和灰度会退回旧的 Web 版本，所以旧版本的 `builds/<buildId>/` 和带哈希的文件要留过后面的部署。
整站替换式的部署会把它们删掉。在构建和部署之间，从线上正在用的产物里把它们带过来：

```bash
npx flare-web-retain-builds --previous /srv/site --out dist --keep 3
```

`--keep` 数的是旧版本，默认 3，`--out` 里的当前版本不算。`--out` 默认 `dist`。先后顺序记在
`builds/history.json`，它要随产物一起部署。缺文件的版本会被丢弃并给出警告，由更早的版本补上。
首次部署用 `--first-deployment` 代替 `--previous`；`--previous` 的目录不存在时直接报错，路径写错不会把旧版本丢掉。

## 可运行的完整示例

本包是 SDK 层，跑起来需要配套的运行时桥与服务端。完整可运行的应用见仓库
[`examples/`](../../examples/)，其中 `flare-core-uni-app` 是接线最完整的一个。

服务端起法见 flare-im-core 仓库的 `QUICKSTART.md`（五分钟跑通，无需自建用户体系）。

## 给贡献者

**不要在这里加 IM 业务逻辑。** 行为应当加进 `flare-im-core-sdk`（Rust），
经 `bindings/c` 暴露，再更新 `sdk-spec/manifest.json`。这个包只做类型化转发 ——
逻辑下沉到核心才能让七个端共享同一份实现。

- 契约状态：`contract-synced`
- 异步模型：Promise + 事件订阅
- FFI 契约：`flare-im-ffi/v1`

## 许可

Apache-2.0
