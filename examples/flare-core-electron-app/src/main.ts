import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import {
  configureProductionStorageBackend,
  sdkMediaProxyFields,
} from "@flare-im/vue-ui/app";
import { configureMediaProxy } from "@flare-im/vue-ui/utils";
import { createSqliteOpfsStorageHost } from "./storage/sqliteOpfsStorageHost";
import "@flare-im/vue-ui/app/style.css";
import { applyFlareTheme } from "@flare-im/vue-ui/theme";

// Electron renderer uses the @flare-im/sdk web client directly (WASM core →
// WebSocket); WASM has no QUIC, so the transport stays WebSocket on every build.
// Storage differs by build target:
//   - packaged desktop app (Electron shell present) → SQLite (wa-sqlite + OPFS, app-owned)
//   - web build (dev:web / preview, no Electron preload) → IndexedDB
const isDesktopShell =
  (window as { flareDesktop?: { runtime?: string } }).flareDesktop?.runtime === "electron";
if (isDesktopShell) {
  configureProductionStorageBackend("sqlite", createSqliteOpfsStorageHost);
} else {
  configureProductionStorageBackend("indexeddb");
}

configureMediaProxy(sdkMediaProxyFields());


// 显式声明主题，且必须在挂载前调用。
//
// kit 的 token 带一层 `@media (prefers-color-scheme: dark)` 兜底：没有人显式
// 定下主题时，它跟着**系统**走。这个 app 的样式几乎全部来自 kit，本身没有
// 对应的深色版式，于是在深色系统下会进入半暗态——文字 token 变白、背景仍浅，
// 会话列表标题一类的文字直接白字白底看不见（tauri app 上已实测复现）。
//
// applyFlareTheme 会注入 token 并同时写 data-theme 与 data-flare-theme，
// 两个属性缺一不可：只设其一会让 --flare-color-* 停在另一套里，仍是半暗态。
//
// 等这个 app 补齐深色版式后，换成 useFlareThemeProvider 跟随用户选择即可；
// 在那之前，声明一个真正实现了的主题，比跟随一个没实现的更诚实。
applyFlareTheme(false, "default");

const app = createApp(App);
app.use(router);
app.mount("#app");
