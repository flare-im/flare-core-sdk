import { createRouter, createWebHashHistory } from "vue-router";
import {
  getFlareSdkSingleton,
  FlareAboutScreen as AboutView,
  FlareChatPlaceholder as ChatPlaceholderView,
  FlareAccessDiagnosticsScreen as NetworkView,
  FlareChatWorkspace as ChatView,
  FlareConversationsPanel as ConversationsView,
  FlareHomeSyncScreen as SyncProgressView,
  FlareLoginScreen as LoginView,
  FlareWorkbenchLayout as WorkbenchLayout,
} from "./workbench/app";

const SdkLabView = () => import("./workbench/app").then((module) => module.FlareSdkLabPanel);

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: "/login", name: "login", component: LoginView, meta: { public: true } },
    { path: "/sync", name: "sync", component: SyncProgressView },
    { path: "/network", name: "network", component: NetworkView },
    { path: "/about", name: "about", component: AboutView },
    {
      path: "/",
      component: WorkbenchLayout,
      children: [
        { path: "", redirect: { name: "conversations" } },
        {
          path: "conversations",
          name: "conversations",
          components: { conversation: ConversationsView, main: ChatPlaceholderView },
        },
        {
          path: "chat",
          name: "chat",
          components: { conversation: ConversationsView, main: ChatView },
        },
        { path: "sdk-lab", name: "sdk-lab", components: { main: SdkLabView } },
      ],
    },
    { path: "/:pathMatch(.*)*", redirect: { name: "conversations" } },
  ],
});

router.beforeEach(async (to) => {
  if (to.meta.public) return true;
  const sdk = getFlareSdkSingleton();
  let loggedIn = sdk?.loggedIn.value ?? false;
  if (!loggedIn && sdk?.hasSavedSession()) loggedIn = await sdk.resumeSavedSession();
  if (!loggedIn) return { name: "login", replace: true };
  // Home sync waits for the connection, and these pages are the way out when the connection cannot come up.
  if (to.name === "network" || to.name === "about") return true;
  if (to.name === "sync") return sdk?.homeSyncReady.value ? { name: "conversations", replace: true } : true;
  if (!sdk?.homeSyncReady.value) return { name: "sync", replace: true };
  if (to.name === "chat" && !sdk?.activeConversationId.value) {
    return { name: "conversations", replace: true };
  }
  return true;
});

export type WorkbenchRouteName = "conversations" | "chat" | "sdk-lab" | "sync";
