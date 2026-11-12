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

`api` / `listener` / `model` / `callback` / `contract` / `media` / `lifecycle` / `notifications`
分别导出操作、事件监听、数据模型、回调、协议契约、媒体、生命周期与系统通知。

## 系统通知（桌面与 Web）

提示与否、怎么提示都由引擎决定（免打扰、勿扰时段、正在看的会话、一个会话一条通知、响铃预算），文案也由它渲染。桌面
与 Web 自己出系统通知：把引擎的 `notification.present` 里 surface 为 `system` 的显示成系统通知，收到
`notification.clear` 时撤掉。一次调用即可：

```ts
import { startSystemNotifications } from "@flare-im/sdk/notifications";

const notifications = startSystemNotifications(client.events, {
  onOpen: ({ conversationId, messageId }) => openConversation(conversationId, messageId),
});

// 在用户操作里调（设置开关、引导页）：浏览器不认非用户操作的申请。
await notifications.requestPermission();   // "granted" | "denied" | "prompt" | "unsupported"

// 登出或卸载时：停止监听，撤掉它显示过的通知。
notifications.stop();
```

- 默认展示方是浏览器的通知：tag 取合并键，同一会话的新通知替换旧的；引擎给了 `sound` 才再次响铃；点击时
  关掉它、把窗口拉到前面并调 `onOpen`（摘要通知不属于任何会话，只拉到前面）。
- 页面受 Service Worker 控制时，经它的注册（`showNotification`）显示，Android Chrome 只认这一种；否则用
  `Notification` 构造函数。`registration` 选项（或 `null`）可以改掉这个选择。这样显示的通知把点击报给 worker，所以
  应用的 `sw.ts` 要转交（见下）。此时 `closeAll()` 撤掉这个注册下的所有通知，之前的页面显示的也一起撤。
- 没授权时什么都不显示，也不报错；`permission()` 读当前权限。
- surface 为 `inApp` 的归应用内横幅（设计库），通知器不管。
- 事件源是任何带 `onNotificationPresent`、`onNotificationClear` 的对象，返回订阅、退订函数或它们的 Promise 都行：
  `client.events` 直接可用，社交 SDK 的 `notification` 模块也可以。
- 应用照样用 `client.notification.setFocus({ conversationId })` 报正在看的会话；桌面与 Web 不调 `setBackgroundPresenter`。

worker 显示的通知，点击落在 worker 里。应用的 `sw.ts` 加一行转给页面，页面像处理其他点击一样打开会话（之前的页面
显示的通知也一样）：

```ts
import { handleFlareNotificationClick } from "@flare-im/sdk/notifications";

self.addEventListener("notificationclick", (event) => handleFlareNotificationClick(event));
```

它关掉通知，给应用最近获得焦点的窗口发一条 `FlareNotificationClickMessage`（`type: FLARE_NOTIFICATION_CLICK`、
合并键、会话与消息 id），并把窗口拉到前面。没有打开的窗口时，在 worker 的 scope（或 `url`）打开应用；这样启动的页面
不会打开那个会话。不是展示方显示的通知它返回 false，不处理。

Tauri 宿主传自己的展示方，基于它的通知插件（示例见英文版 README，接口相同）：`show(notification, activate)`、
`close(collapseIds)`、`closeAll()`、`permission()`、`requestPermission()`，可选 `focus()`。插件按数字 id 管通知，
展示方自己把合并键映射成 id；平台报不出点击时不调 `activate`。在 `show` 之外也能听到点击的展示方（浏览器展示方经
worker）提供 `onActivate(listener)`，通知器同样处理。这个子路径不引入 wasm 运行时，也不引入任何桥。

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
