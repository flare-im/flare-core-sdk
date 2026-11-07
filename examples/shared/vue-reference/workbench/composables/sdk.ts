// **SDK 绑定层**：这里的东西对 `@flare-im/sdk` 有真实运行时依赖。
//
// 单独开一个子路径入口（`@flare-im/vue-ui/composables/sdk`）而不是并进
// `./composables`，原因是 package.json 把 `@flare-im/sdk` 声明为
// `peerDependenciesMeta.optional` —— 要让这个声明成立，**不装 SDK 的消费方
// 必须能用组件库**。而 `src/index.ts` 里有 `export * from "./composables"`，
// 一旦 SDK 绑定挂在那个 barrel 上，任何 `from "@flare-im/vue-ui"` 都会把
// SDK 拖进构建图：flare-social 各端（用 social wasm 核，压根不装 IM 的 TS SDK）
// 直接构建失败，报 `__vite-optional-peer-dep:@flare-im/sdk`。
//
// 本地开发看不出来：示例 app 的 vite alias 把 `@flare-im/sdk` 指向同级仓源码。
// 这个缺陷是切到 published 模式（真装 npm 包）才暴露的。
//
// 往这里加东西的判据：需要 `@flare-im/sdk` 的**值**（不只是类型）就放这里。
// 只要类型就放回 `./composables` —— 类型会被编译擦除，不构成运行时依赖。
// 由 `src/utils/messageContent.contract.test.ts` 的可达性门禁强制。
export {
  useFlareCoreClient,
  desktopNotificationBodyForMessage,
  readLoginEnvText,
  normalizeLoginIdentityForSdk,
  presenceStatusFromCoreDto,
  shouldRefreshTimelineAfterDispatch,
  buildMessageDispatchParams,
  DEFAULT_MARK_COLOR,
  MARK_TYPE_IMPORTANT,
  type UseFlareCoreClientOptions,
  type LoginFormState,
  type LoginIdentity,
  type SdkRuntimeStatus,
  type RuntimeEventLogItem,
  type HomeSyncProgress,
  type SdkLabState,
  type ConversationFilter,
  type ConversationFilterState,
} from "./useFlareCoreClient";
export {
  bindFlareSessionEvents,
  reportSdkError,
  flareSessionBridgeTesting,
  mapSdkError,
  type PresenceChangedHint,
  type ReactionChangedHint,
} from "./useFlareSessionBridge";
