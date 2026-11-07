# 示例应用能力覆盖

契约真源是 `sdk-spec/modules/*.json`——12 个模块、115 个操作。本文记录各示例应用对这些操作的覆盖情况，用于发现示例的功能盲区。`flare-core-flutter-app` 是覆盖最完整的基准实现。

## 示例应用的构成

六个示例应用分两类：

- **原生独立实现**，各自一套 UI：Flutter（Dart）、Android（Kotlin / Compose）、iOS（SwiftUI）。
- **共享 Vue 实现**：web / electron / uni / tauri 四端复用 `packages/@flare-im/vue-ui/app` 暴露的 workbench 组件、SDK context 以及 media/desktop adapter hooks，但各自维护 `App.vue`、`router.ts`、路由守卫、history 模式和平台初始化。因此**UI 业务能力按共享包统计，应用壳与平台集成按各端统计**。

另有 `flare-core-rn-app`（React Native），未纳入本清单。

## 统计方法

对 `sdk-spec` 中的每个操作名（如 `addReaction`、`searchMessages`）在各代码库做 word-boundary 大小写不敏感检索：

| 端 | 检索范围 |
|---|---|
| Flutter | `flare-core-flutter-app/lib` |
| Android | `flare-core-android-app/app/src/main` |
| iOS | `flare-core-ios-app/Sources` |
| web / uni / tauri | 共享包 `packages/@flare-im/vue-ui/src` + 各自 `src/App.vue`、`src/router.ts` |

图例：`✓` 表示操作名出现（强信号，说明被调用），`·` 表示未出现。

**`·` 不等于缺功能。** 有些端使用了等价操作——例如 iOS 用 `listConversationsPaginated` 覆盖 `listConversations` 的场景。判断是否为真实缺口需要人工复核。共享 Vue 三端的 `·` 多数经 `messageDispatchOptions` 的 `dispatchMessage({op})` 覆盖。

## 覆盖总览

| 端 | 覆盖 | 形态 | 说明 |
|---|:--:|---|---|
| Flutter | 112 | 原生 Dart | 基准实现，覆盖最完整 |
| Android | 104 | 原生 Kotlin (Compose) | MVVM 分层 + Compose 六屏 + FlareTheme 设计系统 + 中英双语 |
| web | 98 | Vue + `@flare-im/sdk`（WASM） | 共享 workbench blocks + web 应用壳 |
| uni | 98 | Vue + uni 跨端（`uniFlarePlatform`） | 共享 workbench blocks + uni 应用壳 |
| tauri | 98 | Vue + `@flare-im/sdk/tauri`（桌面 / Rust） | 共享 workbench blocks + Tauri 应用壳 |
| iOS | 96 | 原生 SwiftUI | MVVM 分层 + String Catalog 双语 + 平台服务收敛 + 设计 token |

web / uni / tauri 三列数值相同，因为它们共享同一套 Vue UI。三者的真实差异在平台集成层：

| 维度 | web | uni | tauri |
|---|---|---|---|
| 客户端 SDK | `@flare-im/sdk`（WASM core） | 共享 Vue + `uniFlarePlatform` 适配 | `@flare-im/sdk/tauri`（Rust 桌面后端） |
| 运行形态 | 浏览器 | App / H5 / 小程序 | 桌面（`src-tauri` Rust 后端） |
| 媒体 | 媒体代理 / Cache API | SQLite 本地库 / 原生录音 | 本地路径解析 + 文件选择器 |
| 原生能力 | — | 原生录音、SQLite | 桌面通知、文件对话框、传输选择器、dev CA 证书 |
| 应用壳 | `src/main.ts` | `pages/index/index.vue` + `manifest.json` | `src/main.ts` + `desktopNotifications.ts` + `src-tauri` |

## 各端说明

**Flutter** —— 未覆盖的三项：`events.subscribeEvents`（已用 `subscribeEventsBatch` 等价覆盖）、`views.loadOlderTimeline`、`sync.syncConversationSummariesWithVersions`。

**Android** —— `flare-core-android-sdk` 本身 1:1 暴露全部 115 个操作，示例应用覆盖 104 个。分层为 `core/{session,data,domain}` 加五个特性 ViewModel，其中 `ViewDataRepository` 采用 re-fetch-on-signal 策略（Kotlin SDK 无 snapshot/delta 解码器，`onViewUpdated` 后重拉 typed 快照）。剩余 11 个 `·` 均为等价覆盖：`getConversation` / `getMultipleConversations` 走 `getOne`，`listConversationsByQuery` 走 paginated 变体，`deleteMessage` / `markMessage` / `pinMessage` / `unmarkMessage` / `unpinMessage` 走 `*ById` 或 ForSelf/ForEveryone 变体，`dispatchMessage` / `editRichDocByMessageId` 走 send / editText，`syncConversationSummariesWithVersions` 走 summaries。

> 接线注意：SDK 多数动作方法签名为 `Map<String, Any?>`。类型归属容易记错——`ForwardSourceMessage` 在 content，`MediaSourceInfo` 在 media，`Normalize*` / `Heartbeat*` 在 command，`MessageSearchKind` 在 common.enums。

**iOS** —— 五个 ViewModel 加 `Core/Session/AppLifecycle` 协议，视图层不直接调用 store；平台相关代码收敛在 `Core/Platform/`（Image / Clipboard / AudioSession），`#if canImport` 集中而非散落；`MessageBuilder` 独立于 `MessagingViewModel`；`FlareDesign` 提供 `Radius` / `Spacing`（4pt 网格）/ `Typography` 标尺。

复核为等价覆盖而非缺口的操作：`pinMessage` / `unpinMessage` / `markMessage` / `unmarkMessage`（用 `*ById`）、`listConversations`（用 paginated）、`getMessage`（用 `getRawMessage`）、`getConversation` / `getMultipleConversations`（用 `getOneConversation`）、`subscribeEventsBatch`（用 `subscribeEvents`）、`openConversationTimeline`（用 `views.openTimeline`）、`createTextMessage` / `dispatchMessage`（经 send / builder）、`editRichDocByMessageId`（有 `editTextByMessageId`）、`listConversationsByQuery` / `listConversationsIncludingArchived`（paginated 变体）。

`session.connect` 记为 `·`：连接由 `client.init` + `client.login` 隐式建立，代码中没有独立的 `connect()` 调用，登录后读 `client.connection.getStatus()`，之后跟随 `connection://status`。

**web / uni / tauri** —— 共享 Vue 包的改动三端同时生效。八个操作经 `dispatchMessage({op})` 等价覆盖，不为其增加冗余的具名包装：`deleteMessageForEveryone`、`editRichDocByMessageId`、`markMessageReadAndBurn`、`markMessageWithColor`、`unmarkMessage`、`unpinMessage`，以及 `subscribeEventsBatch` → `subscribeEvents`、`syncConversationSummariesWithVersions` → `syncConversationSummaries`。

平台层缺口需各端单独补：web 的媒体代理边界与可选 PWA；uni 的小程序兼容、原生录音与 SQLite 回归；tauri 的桌面通知、文件对话框、托盘等原生能力及 `src-tauri` 命令面。

## 运行方式

- **Flutter / Android**：常规构建即可运行。
- **iOS**：先用 `scripts/sync_ffi.sh` 同步 FFI 产物，工程由 `project.yml`（xcodegen）生成，静态链接模拟器 `.a` 并加 `-force_load` / `-export_dynamic`。详见 `flare-core-ios-app/README.md`。
- **web**：`npm install` + 构建 core 后 `vite dev`；**uni**：走 uni 端构建；**tauri**：`tauri dev`（含 `src-tauri` Rust 构建）。

需要连接后端才能真正执行的操作（上传、删除等）须先登录。

`connection.notifyNetworkChange` 与 `lifecycle.setAppState` 在各示例中都记为 `·`，这是有意的：网络与前后台上报由平台包在 `init` 时自动安装的 PlatformLifecycle 完成，示例不再手写接线。连到哪里由初始化配置的 `access`（签名清单或开发模式 `developmentEndpoints`）决定，示例登录页没有服务器地址设置。

## 补齐优先级

1. **共享 Vue 三端的 UI 缺口**——改一次三端受益，性价比最高；动手前先复核 `·` 是否为真实缺口。
2. **各端平台集成层**——这部分无法共享，只能逐端补。
3. 每补一批跑各端 parity 测试（uni 已有 `tests/uni-app-parity.test.mjs`，Android / iOS 可补类似断言对照本表）。

## 完整矩阵（115 操作 × 6 端）

`✓` 表示操作名出现，`·` 表示未出现（其中部分为等价覆盖，见上文）。web / uni / tau 三列相同，因为共享同一套 Vue UI。

| module.operation | Flu | And | iOS | web | uni | tau |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| capabilities.dispatchCapability | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| capabilities.grantCapability | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| capabilities.listCapabilities | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| capabilities.listUserCapabilities | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| capabilities.revokeCapability | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| connection.disconnect | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| connection.getStatus | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| connection.notifyNetworkChange | · | · | · | · | · | · |
| connection.reconnectNow | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| access.listAccessPoints | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.bootstrapHomeTimeline | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.clearLocalChatHistory | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.deleteConversation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.getConversation | ✓ | · | · | · | · | · |
| conversations.getGroupConversationByUserIds | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.getMultipleConversations | ✓ | · | · | · | · | · |
| conversations.getOneConversation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.listConversations | ✓ | ✓ | · | ✓ | ✓ | ✓ |
| conversations.listConversationsByQuery | ✓ | · | · | ✓ | ✓ | ✓ |
| conversations.listConversationsIncludingArchived | ✓ | ✓ | · | ✓ | ✓ | ✓ |
| conversations.listConversationsPaginated | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.listRawConversations | ✓ | ✓ | ✓ | · | · | · |
| conversations.markConversationRead | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.markConversationUnread | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.openConversationTimeline | ✓ | ✓ | · | · | · | · |
| conversations.setConversationArchived | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.setConversationMuted | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.setConversationPinned | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| conversations.updateConversationDraft | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| diagnostics.getDataRoot | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| diagnostics.getFfiContractVersion | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| diagnostics.getRuntimeHealth | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| diagnostics.getSdkVersion | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| events.subscribeEvents | · | ✓ | ✓ | ✓ | ✓ | ✓ |
| events.subscribeEventsBatch | ✓ | ✓ | · | · | · | · |
| events.unsubscribe | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| events.unsubscribeAll | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.cacheRemoteMedia | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.cancelUserFileDownload | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.clearMediaCache | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.deleteFile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.deleteUserDownloadRecord | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.downloadFileToDownloads | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.getMediaCacheStats | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.getMediaUrl | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.getTempDownloadUrl | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.getUserDownloadSavedPath | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.getUserDownloadSubfolder | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.resolveMediaAccess | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.setMediaCacheMaxBytes | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.setMediaCacheRoot | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.setUserDownloadSubfolder | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.uploadBytes | ✓ | ✓ | · | ✓ | ✓ | ✓ |
| media.uploadFile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.uploadImage | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| media.uploadVideo | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| message_builder.listSupportedBuildOperations | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| message_builder.normalizeRichDocFromDocJson | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| message_builder.normalizeRichDocFromHtml | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| message_builder.normalizeRichDocFromMarkdown | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.addReaction | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.createTextMessage | ✓ | ✓ | · | · | · | · |
| messages.deleteMessage | ✓ | · | · | ✓ | ✓ | ✓ |
| messages.deleteMessageForEveryone | ✓ | ✓ | ✓ | · | · | · |
| messages.deleteMessageForSelf | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.dispatchMessage | ✓ | · | · | ✓ | ✓ | ✓ |
| messages.editRichDocByMessageId | ✓ | · | · | · | · | · |
| messages.editTextByMessageId | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.getMessage | ✓ | ✓ | · | · | · | · |
| messages.getRawMessage | ✓ | ✓ | ✓ | · | · | · |
| messages.listMessages | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.markMessage | ✓ | · | · | ✓ | ✓ | ✓ |
| messages.markMessageById | ✓ | ✓ | ✓ | · | · | · |
| messages.markMessageReadAndBurn | ✓ | ✓ | ✓ | · | · | · |
| messages.markMessageWithColor | ✓ | ✓ | ✓ | · | · | · |
| messages.pinMessage | ✓ | · | · | ✓ | ✓ | ✓ |
| messages.pinMessageById | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.recallMessage | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.removeReaction | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.searchMessages | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.searchMessagesByQuery | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.searchMessagesInConversation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.sendMessage | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.sendMessageNoOss | ✓ | ✓ | ✓ | · | · | · |
| messages.setTyping | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| messages.unmarkMessage | ✓ | · | · | · | · | · |
| messages.unmarkMessageById | ✓ | ✓ | ✓ | · | · | · |
| messages.unpinMessage | ✓ | · | · | · | · | · |
| messages.unpinMessageById | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| presence.batchGetUserPresence | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| presence.getUserPresence | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| presence.subscribeUserPresence | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.connect | ✓ | ✓ | · | ✓ | ✓ | ✓ |
| session.create | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.currentUserId | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.dispose | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.hardReset | ✓ | ✓ | ✓ | · | · | · |
| session.heartbeatEffectiveInterval | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.init | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.isConnected | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.login | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.logout | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.prepare | ✓ | ✓ | ✓ | · | · | · |
| session.sessionActive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.setHeartbeatNatTimeout | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| session.uninit | ✓ | ✓ | ✓ | · | · | · |
| session.updateAccessToken | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| sync.syncConversation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| sync.syncConversationSummaries | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| sync.syncConversationSummariesWithVersions | · | · | · | · | · | · |
| sync.syncMessages | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| views.close | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| views.loadOlderTimeline | · | ✓ | ✓ | ✓ | ✓ | ✓ |
| views.openConversationList | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| views.openTimeline | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
