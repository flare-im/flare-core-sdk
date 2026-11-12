import { createRouter, createWebHashHistory } from "vue-router";
import {
  getFlareSdkSingleton,
  FlareChatPlaceholder as ChatPlaceholderView,
  FlareChatWorkspace as ChatView,
  FlareConversationsPanel as ConversationsView,
  FlareHomeSyncScreen as SyncProgressView,
  FlareLoginScreen as LoginView,
  FlareWorkbenchLayout as WorkbenchLayout,
} from "@flare-im/vue-ui/app";

// Views come from the shared @flare-im/vue-ui/app workbench building blocks.
// Platform specifics are injected outside these views: SQLite/OPFS storage via
// configure* adapters in main.ts, the engine's notifications in App.vue.
const SdkLabView = () =>
  import("@flare-im/vue-ui/app").then((m) => m.FlareSdkLabPanel);

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: "/login",
      name: "login",
      component: LoginView,
      meta: { public: true },
    },
    {
      path: "/sync",
      name: "sync",
      component: SyncProgressView,
    },
    {
      path: "/",
      component: WorkbenchLayout,
      children: [
        { path: "", redirect: { name: "conversations" } },
        {
          path: "conversations",
          name: "conversations",
          components: {
            conversation: ConversationsView,
            main: ChatPlaceholderView,
          },
        },
        {
          path: "chat",
          name: "chat",
          components: {
            conversation: ConversationsView,
            main: ChatView,
          },
        },
        {
          path: "sdk-lab",
          name: "sdk-lab",
          components: {
            main: SdkLabView,
          },
        },
      ],
    },
    { path: "/:pathMatch(.*)*", redirect: { name: "conversations" } },
  ],
});

router.beforeEach(async (to) => {
  if (to.meta.public) return true;
  const sdk = getFlareSdkSingleton();
  let loggedIn = sdk?.loggedIn.value ?? false;
  if (!loggedIn && sdk?.hasSavedSession()) {
    // 热启动：本地会话档案存在时先本地出图再后台建连，跳过登录页
    loggedIn = await sdk.resumeSavedSession();
  }
  if (!loggedIn) return { name: "login", replace: true };
  if (to.name === "sync") {
    return sdk?.homeSyncReady.value ? { name: "conversations", replace: true } : true;
  }
  if (!sdk?.homeSyncReady.value) {
    return { name: "sync", replace: true };
  }
  if (to.name === "chat" && !sdk?.activeConversationId.value) {
    return { name: "conversations", replace: true };
  }
  return true;
});

export type WorkbenchRouteName = "conversations" | "chat" | "sdk-lab" | "sync";
