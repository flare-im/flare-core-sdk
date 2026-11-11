import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const contracts = [
  ["../flare-core-examples/shared/vue-reference/ReferenceApp.vue", ["provideFlareSdk", "createAppMediaResolver"]],
  ["../flare-core-examples/shared/vue-reference/workbench/app/sdk/flareSdkContext.ts", ["createProductionAppClient", "createClient: createProductionAppClient"]],
  ["../flare-core-examples/shared/vue-reference/workbench/composables/useFlareCoreClient.ts", ["options.createClient()", "subscribeEvents", "client.messages.sendMessage"]],
  ["../flare-core-examples/shared/vue-reference/router.ts", ["FlareWorkbenchLayout", "FlareChatWorkspace", "resumeSavedSession"]],
  ["../flare-core-examples/apps/flare-core-web-app/src/integration/referenceRuntime.ts", ["WebFlareImClient", "WebProductionBridge", "createWasmRuntime"]],
  // P0-2 moved the Tauri media picker onto the platform adapter, and
  // ../flare-core-examples/apps/flare-core-tauri-app/tests/transport-selector.test.mjs now asserts the
  // runtime does NOT mention configureAppMediaPathPicker — this contract required
  // the very thing that test forbids, so the pair was unsatisfiable. The uni-app
  // runtime still uses configureAppMediaPathPicker; Tauri wires the adapter.
  ["../flare-core-examples/apps/flare-core-tauri-app/src/integration/referenceRuntime.ts", ["FlareCoreSdk.createClient", "createTauriPlatformAdapter", "setUnreadCount"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/shell/workbench_shell.dart", ["FlareIMAppKit"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/infrastructure/sdk/flare_core_sdk_wrapper.dart", ["FlareCoreFlutter.createClient", "sendMessage"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/shell/FlareApp.kt", ["IMAppKit"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/core/session/AppSession.kt", ["FlareImClient", "sdk.connect", "subscribeEvents"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Shell/RootWorkbenchView.swift", ["IMAppKitView"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Core/Session/AppSession.swift", ["FlareImClientProtocol", "client.connect", "installEventSubscriptions"]],
];

const focusedReferenceSurfaces = [
  ["../flare-core-examples/shared/vue-reference/ReferenceApp.vue", [/id:\s*"contacts"/, /id:\s*"groups"/, /Flare(?:Contact|Friend|Group|Relation)/]],
  ["../flare-core-examples/apps/flare-core-web-app/src/router.ts", [/contacts/, /groups/]],
  ["../flare-core-examples/apps/flare-core-tauri-app/src/router.ts", [/contacts/, /groups/]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/shell/workbench_shell.dart", [/id:\s*'contacts'/, /id:\s*'groups'/]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/router/app_router.dart", [/path:\s*'\/contacts'/, /path:\s*'\/groups'/]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/shell/FlareApp.kt", [/FlareApplicationNavigationItem\("contacts"/, /FlareApplicationNavigationItem\("groups"/]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Shell/RootWorkbenchView.swift", [/\.init\(id:\s*"contacts"/, /\.init\(id:\s*"groups"/]],
];

for (const [relative, symbols] of contracts) {
  const absolute = path.join(root, relative);
  if (!fs.existsSync(absolute)) {
    failures.push(`${relative}: assembly file is missing`);
    continue;
  }
  const source = fs.readFileSync(absolute, "utf8");
  for (const symbol of symbols) {
    if (!source.includes(symbol)) failures.push(`${relative}: missing assembly contract ${symbol}`);
  }
}

for (const [relative, patterns] of focusedReferenceSurfaces) {
  const source = fs.readFileSync(path.join(root, relative), "utf8");
  for (const pattern of patterns) {
    if (pattern.test(source)) {
      failures.push(`${relative}: reference apps focus on conversations/messages and must not expose contact, group-directory, or relationship navigation`);
    }
  }
}

if (failures.length) {
  console.error(`real-sdk-example-assembly-check failed:\n${failures.map((item) => `- ${item}`).join("\n")}`);
  process.exit(1);
}

console.log("real-sdk-example-assembly-check passed");
