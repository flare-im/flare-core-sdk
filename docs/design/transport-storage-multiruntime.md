# Flare IM 客户端 — 多端传输与存储架构设计报告

> 范围:`packages/@flare-im/sdk` 结构与 `src/adapters` 优化;
> `examples/flare-core-electron-app`、`examples/flare-core-uni-app` 的补全。
> 目标剖面:Web/H5 = WebSocket + IndexedDB;PC/Android/iOS = WebSocket + QUIC + 协议竞速 + SQLite。

## 0. 一句话结论

传输竞速与存储引擎是 **runtime 的函数,而行为归属 Rust core**。当前 Web/H5(WASM 路径)
已正确落地 WebSocket+IndexedDB;Tauri、uni-app 已正确接入原生 core(QUIC+WS 竞速 + SQLite);
**唯独 Electron 仍跑在 WASM 渲染进程路径上**——它对外宣称 `electron-native`、UI 暴露 QUIC/竞速
选择器,但没有任何原生桥,实际只能 WebSocket+IndexedDB。本报告给出:(1) `src/adapters` 的
结构收敛;(2) 把被困在 UI 包里的传输/存储基础设施下沉到 SDK 包;(3) 用"主进程原生 core + IPC 桥"
关闭 Electron 缺口的完整设计。

---

## 1. 现状架构(实测)

### 1.1 分层

```
examples/<app>            产品组合 / 路由 / 主题            (web, electron, uni, tauri, rn, flutter, android)
  └─ @flare-im/vue-ui                                  共享 Vue UI + 应用基础设施(composables/app/infrastructure)
       └─ @flare-im/sdk                        L2:类型化 API + Bridge 选择 + codec
            └─ flare-im-core-sdk (Rust)                    L1 行为核心:传输竞速 / 排序 / 同步 / 存储引擎
                 ├─ bindings/wasm  → 浏览器 WASM           WS(JS host)+ IndexedDB(host 回调)
                 └─ bindings/c     → 原生 cdylib/静态库     QUIC + WS 竞速 + SQLite(进程内)
```

### 1.2 Bridge 选择真相表

| Runtime | 入口 adapter | NativeBridge | 实际传输 | 实际存储 | 状态 |
|---|---|---|---|---|---|
| Web | `adapters/web` → `WebProductionBridge` | WASM | WebSocket | IndexedDB | ✓ 符合目标 |
| uni-app H5 | `adapters/uni-app`(auto) | WASM | WebSocket | IndexedDB | ✓ |
| uni-app App | `adapters/uni-app`(auto) | `FfiNativeBridge` → 原生 core | QUIC+WS 竞速 | SQLite | ✓(依赖原生插件已编译) |
| Tauri | `adapters/tauri` → `TauriNativeBridge` | 原生 core | QUIC+WS 竞速 | SQLite | ✓ |
| RN | `adapters/react-native` | `FfiNativeBridge` | QUIC+WS 竞速 | SQLite | ✓ |
| **Electron** | **无专属 adapter** | **回退 `WebProductionBridge`(WASM)** | **仅 WebSocket** | **IndexedDB** | ✗ **缺口** |

证据:`examples/flare-core-electron-app/src/main.ts` 调了
`configureAppTransportSelector({ runtimeStatus: "electron-native" })`,但**没有**调
`configureProductionAppClientFactory(...)`;而 uni-app/tauri 的 `main.ts` 都调了。于是
`createProductionAppClient()` 命中默认分支,构造 `WebProductionBridge`(WASM)。
Electron 的 `preload.ts` 只暴露通知/文件揭示,**没有任何 SDK 原生 FFI 通道**;全仓库
也搜不到 `napi/koffi/ffi-napi`。结论:Electron 当前不可能达成 QUIC/SQLite,选了 QUIC/竞速
会在 WASM core 返回 "QUIC transport feature is disabled" 后回退 WS。

### 1.3 传输策略模型(已存在,设计良好)

`useFlareCoreClient.ts` 的 `buildLoginTransportConfig()` 已把登录态映射为 core 的
`SdkConfig`:`transportPolicy`(`websocket_only` / `auto` / `protocol_race`)、`defaultTransport`、
`protocolRaceOrder`(`["quic","websocket"]`)、`tlsCaCertPath`。**竞速算法在 Rust core,TS 只传配置**
——这是正确的归属,予以保留。

---

## 2. 结构问题诊断(回答"优化 adapters 与整体结构")

1. **传输/存储真实现被困在 UI 包。** 生产级 WASM 桥 `webProductionBridge.ts`(313 行,含连接态机、
   超时、事件管线、best-effort 节流)与 IndexedDB 存储 host `idbWasmStorageHost.ts`(384 行)位于
   **`@flare-im/vue-ui/app/infrastructure`**(UI 包),而 SDK 自己的
   `adapters/web/webFlareImClient.ts` 只是 16 行壳。按 flare-im-spec 约束 5「可复用客户端基础设施下沉
   packages」,这两块是 **product-neutral 的传输/存储基础设施**,应下沉到
   `@flare-im/sdk/src/adapters/web`,让任何宿主(不止 Vue UI、含 Electron 渲染回退)都能复用。

2. **`src/adapters` 缺少"运行时剖面"这一一等概念。** 现在每个 adapter 的 `flareCoreSdk.ts` 只做
   bridge 选择,传输能力(能否 QUIC、存储是 sqlite 还是 idb)散落在 UI 包的
   `appTransportSelector` + `useFlareCoreClient`。Electron 能宣称 native 却无法兑现,正是因为
   "剖面"没有单一权威来源。

3. **Electron 无 adapter。** `web/tauri/uni-app/react-native` 四个剖面齐全,独缺 `electron`。

4. **`useFlareCoreClient.ts` 3289 行的上帝 composable**(传输配置+登录+会话列表+聊天+SDK Lab+媒体+诊断)。
   非本次硬目标,但传输配置部分应随基础设施一起下沉,顺手减负。

---

## 3. 目标架构与层归属(设计核心产物)

### 3.1 归属决策表(按 flare-im-spec 放置规则)

| 关注点 | 归属 | 理由 |
|---|---|---|
| 协议竞速算法(QUIC/WS、happy-eyeballs、回退、重连、race order) | **flare-im-core-sdk (Rust)** | 产品中立、各端一致 → core(已具备) |
| 存储引擎语义(SQLite schema、批写、淘汰、snapshot/cursor) | **flare-im-core-sdk (Rust)** | 各端语义一致 |
| 原生 socket(QUIC/UDP、WS)+ SQLite 文件 I/O | **Rust core 进程内**(tauri/rn/uni-native/electron-native) | core 有 OS 权限时直接做 |
| WASM 缺失能力的浏览器 host 钩子:WS 传输、IndexedDB 持久化 | **packages(TS)→ `adapters/web`** | WASM 开不了原生 socket/SQLite,由 host 提供 |
| Bridge 选择 / 运行时剖面 | **packages → `typescript-sdk/src/adapters/<runtime>`** | 薄、生成器拥有 |
| 传输配置映射(mode → SdkConfig) | **packages(typescript-sdk)** | 现位于 UI composable,产品中立应下沉 |
| 登录表单、屏幕流、主题 | **examples/<app>** | 产品/UI |

### 3.2 引入单一权威:`TransportProfile`(SDK 包拥有)

```ts
// adapters/<runtime> 各自声明
interface TransportProfile {
  runtime: 'web' | 'electron' | 'uni-native' | 'uni-h5' | 'tauri' | 'react-native';
  transports: ('quic' | 'websocket')[];   // 该 runtime 物理上支持哪些
  defaultTransport: 'quic' | 'websocket';
  raceOrder: ('quic' | 'websocket')[];     // 竞速顺序(空=不竞速)
  storage: 'sqlite' | 'indexeddb';
  native: boolean;                          // 是否运行原生 core
}
```

- Web/uni-H5:`{ transports:['websocket'], storage:'indexeddb', native:false }`
- Electron/Tauri/uni-native/RN:`{ transports:['quic','websocket'], raceOrder:['quic','websocket'], storage:'sqlite', native:true }`

**收益:UI 只读剖面、只能在剖面允许范围内覆盖**。"Electron 宣称 QUIC 却给不出"这类 bug 从根上消除
——剖面是唯一真相,登录选择器据此显示/隐藏 QUIC。运行时降级时(原生加载失败)剖面自动降为
`websocket_only`,UI 绝不提供兑现不了的协议。

### 3.3 `src/adapters` 收敛后形态

```
src/adapters/
  web/            wasm + ws + indexeddb(下沉 webProductionBridge + idbWasmStorageHost)
  electron/       新增:ElectronNativeBridge(渲染端 IPC → 主进程原生 core)
  tauri/          现有:TauriNativeBridge
  uni-app/        现有:FFI(native) / WASM(h5) 自动分流
  react-native/   现有:FFI
  _shared/        TransportProfile 类型、传输配置映射(从 useFlareCoreClient 下沉)
```
每个 adapter 导出 `createClient()`,返回该 runtime **完整接好**的 `FlareImClient`(bridge + host 能力 +
传输默认),examples 不再手搓基础设施。

---

## 4. 关闭 Electron 缺口(最难路径)

### 4.1 设计决策:Electron 在**主进程跑原生 core**,经 IPC 暴露给渲染进程

- 渲染进程 = Chromium → 只能 WASM → 仅 WS+IndexedDB(现状)。
- 主进程 = Node.js → 可加载与 tauri/uni-native **同一份** `bindings/c` cdylib → QUIC+WS 竞速 + SQLite。

这是满足"PC 支持 WebSocket+QUIC+竞速+SQLite"的**唯一**方案,且与原生路径完全复用。

### 4.2 落地组件

1. **`adapters/electron/ElectronNativeBridge`**(实现 `NativeBridge`):渲染端把每个
   `invoke(descriptor, request)` 经 `ipcRenderer.invoke('flare:native', op, payloadJson, descriptorJson)`
   转发;事件经 `ipcRenderer.on('flare:native-event')` 回流进 `DefaultEventsApi`(完全对标
   `TauriNativeBridge.attachEventEmitter`)。
2. **`electron/main.ts`**:用 **koffi** 加载 cdylib(复用 `bindings/c`,无需 Rust/Node 构建胶水),
   `ipcMain.handle('flare:native', …)` → `nativeHost.invoke(…)`;core 事件 → `webContents.send('flare:native-event', …)`。
   SQLite 数据目录置于 `app.getPath('userData')`。
3. **`preload.ts`**:`contextBridge` 暴露最小类型化 `flareNative = { invoke, onEvent }`,安全姿态同既有 `flareDesktop`。
4. **示例补全**:`main.ts` 增加缺失的 `configureProductionAppClientFactory(() => createElectronClient())`。

### 4.3 优雅降级(一条干净回退,诚实暴露)

原生 addon 加载失败(架构不支持 / 开发环境未构建)→ 主进程报 `native:false` → 渲染进程回退
`WebProductionBridge`(WASM+WS+IndexedDB),剖面降级 `websocket_only`,UI 不再提供 QUIC。
**绝不静默撒谎**。

### 4.4 多窗口(Electron 专属硬路径)

多 `BrowserWindow` 共享**主进程内单一 core/SQLite**:单写者,事件扇出到所有 `webContents`,
invoke 汇聚到唯一 core。禁止每窗口一个 core、禁止两进程开同一 SQLite。

---

## 5. 硬路径(IM 系统的生死线)

1. **协议竞速 & 首帧就绪**:竞速归 core(`protocolRaceOrder:['quic','websocket']`);冷启动→可交互 < 500ms 主线程。
   原生优先 QUIC 0-RTT 恢复,WS 为底线。UI 立即乐观显示"连接中",首帧不阻塞于哪个协议胜出;回退由 core 驱动发连接事件,
   现有 `loginTransportFallbackMessage` 文案保留在 UI 层。
2. **存储写路径永远离开交互线程**:原生由 core 在自有线程写 SQLite,渲染进程不碰磁盘;Web 的 `setStorageHost`
   为异步 IndexedDB。WASM 的 `invokeChain` 串行化必须保留(wasm32 上 Tokio `block_on` 不可重入)。乐观回显 <16ms,
   异步持久化,ack 后对账。
3. **事件管线一致性**:原生桥(tauri/electron/ffi)经 host 回调 → `DefaultEventsApi.emit`;WASM 经 `setEventCallback`。
   全部收敛到同一类型化事件信封——这正是各端行为一致的保证。Electron IPC 事件通道须保序(单通道)、带背压
   (洪泛下丢弃 best-effort typing,对标 `isBestEffortControlOperation`)。

## 6. 取舍(明说放弃了什么)

- **主进程原生 core(选)** vs WASM-in-渲染(现状)vs WebTransport/HTTP3-in-渲染:后两者都给不出真正 QUIC + SQLite 文件,
  不满足需求。原生方案代价是 per-arch addon 构建 + electron-builder 打包矩阵,但唯一达标且复用 tauri/uni 原生路径。**接受此代价**。
- **koffi FFI(选)** vs N-API addon:koffi 直接 load 既有 cdylib、零构建胶水、最快落地;N-API 单调用更快、类型更干净但多一个构建目标。
  **先 koffi**(cdylib 走 `extraResources`),若单调用开销显现再上 N-API。两者都把行为留在 core。
- **下沉 web 桥到 SDK 包(选)** vs 留 UI 包:下沉一次性解耦传输/存储与 Vue,解锁 Electron 渲染回退与未来非 Vue 宿主;代价是改动 vue-im-ui 的 import。值得。

## 7. 性能与平滑度预算

- 发送→回显 <16ms:乐观不变,各端持久化异步。
- 冷启→就绪 <500ms:原生 core init 在 UI 线程外(IPC/FFI 异步);WASM init 已在 `ensureRuntime` 后惰性化。
- 列表 60fps:不变(虚拟化在 UI 组件)。
- 存储:原生 SQLite 由 core 淘汰约束;IndexedDB host 已清理非规范行。无无界增长。
- Electron IPC:控制面 payload 为 JSON 字符串(与 FFI 同线);大媒体走既有媒体 adapter / 文件路径,**不**经控制 IPC 序列化大 blob,保证控制通道在帧预算内。

## 8. 可扩展性与风险

- 新增 runtime = 新 adapter 目录 + 一个 `TransportProfile` + 一个 bridge;剖面驱动 UI → 每个 runtime 零 UI 改动。
- 风险:Electron 原生 addon per-arch 打包(mac arm64/x64、win、linux)→ electron-builder `extraResources` 带 cdylib + koffi,WASM 回退兜底。
- 风险:契约版本漂移 → 两类桥已断言 `flareBindingContractVersion` / `diagnostics.ffi_contract_version`;Electron 桥须在主进程做一次同样校验。
- 风险:多窗口 SQLite → 强制单 core-in-main,文档化。
- **开放问题(计划第一步须核实)**:`flare-core-sdk-engine/bindings/c` 是否已为 mac/win/linux 产出桌面 cdylib,还是仅移动端静态库?
  这决定 koffi-vs-N-API 以及打包脚本。

## 9. 实施计划骨架(交由 planning-with-files 展开)

1. 核实桌面 cdylib 可用性(开放问题)。
2. 下沉 `webProductionBridge` + `idbWasmStorageHost` → `adapters/web`;vue-im-ui 改为消费。
3. 在 `adapters/_shared` 落地 `TransportProfile` + 传输配置映射(从 `useFlareCoreClient` 抽离)。
4. 新增 `adapters/electron`:`ElectronNativeBridge` + `createElectronClient()`;UI 剖面读取。
5. Electron 示例:`electron/main.ts` koffi 加载 core + IPC handler;`preload.ts` 暴露 `flareNative`;`src/main.ts` 注册 factory;cdylib 入 `extraResources`;原生失败回退 WASM。
6. uni-app 示例:核实原生插件链路 + 补 README;H5 路径确认 WS+IndexedDB。
7. 验证:契约版本校验、`verify:architecture`、各端 typecheck/test、Electron e2e(QUIC 竞速 + 原生失败回退两条用例)。

> 约束基线:无兼容冗余(删旧留新一条路)、行为下沉 core、可复用基础设施下沉 packages、热路径预算达标、契约传播顺序 core→bindings→sdk-spec→packages。

## 10. 实施状态(2026-06-26,含方向调整)

### 10.1 关于 Electron + QUIC 的最终结论(实地核实)
- flare-core 的 QUIC = **裸 `quinn`(over UDP)**,**非 WebTransport/HTTP3**(全仓库无 webtransport)。
- **WASM build 把 quinn `#[cfg(not(target_arch="wasm32"))]` 编译掉**;WASM 端只有 `web_sys::WebSocket`;**传输无 host 注入口**(仅 `setStorageHost`/`setEventCallback`)。
- ⇒ Electron 渲染进程(WASM)**物理拿不到 QUIC**;Chromium 的 WebTransport 也说不了裸 quinn。裸 QUIC 必须跑原生 Rust core(napi/FFI/sidecar)。
- **决策(用户)**:app 不用 napi-rs、直接用 ts-sdk。⇒ **Electron = WebSocket**(任何构建);**QUIC + SQLite 的桌面客户端走 Tauri**(进程内 Rust core)。

### 10.2 Electron 的最终形态:WS + 按构建目标选存储
| 构建 | 传输 | 存储 |
|---|---|---|
| web 构建(`dev:web`/`preview`,无 Electron) | WebSocket | IndexedDB |
| 打包桌面应用(Win/Mac,Electron 壳) | WebSocket | **SQLite(wa-sqlite + OPFS)** |

存储后端 = WASM core 可注入的 `setStorageHost`:web 用 IndexedDB host;桌面换 `sqliteOpfsStorageHost`(wa-sqlite 真 SQLite 引擎,OPFS 文件持久化,跑在 Web Worker)。**零原生模块、零 napi-rs**。

### 10.3 已完成并验证(typecheck/单测/无漂移全部通过)
- **结构下沉(§2.1)**:`webProductionBridge`+`idbWasmStorageHost` 下沉 `typescript-sdk/src/adapters/web`(注入式 `loadRuntime`);`wasmLoader` 留 UI 注入。
- **存储 host 可注入**:`WebProductionBridge` 增 `createStorageHost?`(默认 IndexedDB)。
- **SQLite host(app 自有)**:`examples/flare-core-electron-app/src/storage/{sqliteOpfsStorageHost,sqliteOpfsWorker}.ts` + `wa-sqlite.d.ts`(wa-sqlite+OPFS,4 张 KV 表镜像 IndexedDB host 键策略 + storage-changed 事件)。**共享包不 import wa-sqlite**——只有 electron 用,按放置规则归示例;web/H5/uni/tauri 包零 wa-sqlite。
- **后端选择**:`configureProductionStorageBackend('indexeddb' | 'sqlite', hostFactory?)`(sqlite 必须显式传 host 工厂);electron `src/main.ts` 据 `flareDesktop.runtime==='electron'` 注入 app 自有的 `createSqliteOpfsStorageHost`。
- **TransportProfile(§3.2)**:`adapters/_shared/transportProfile.ts` + `./transport` 导出;登录屏 `enabled && profileSupportsQuic` 消费。
- **uni-app**:FFI/WASM 自动分流核实正确 + README 传输矩阵。
- **napi-rs 方案全部撤除**:删 `examples/.../native` 插件、app 原生接线;**移除 ts-sdk electron adapter**(xtask 模板 + bridge.rs + generated + `./electron` 导出,`cargo xtask bridge` 重生成无漂移)。

### 10.4 仅剩(需真实构建/运行环境)
SQLite(wa-sqlite/OPFS)路径需:装 `wa-sqlite` 依赖 + Vite worker/WASM 资产配置 + **打包 Electron 运行认证**(OPFS 在 Node/SSR 不可用)。本环境只能 typecheck;IndexedDB 仍是 web 已验证默认。
