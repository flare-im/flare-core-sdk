import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const removedUiIslands = [
  "../flare-core-examples/apps/flare-core-web-app/src/views",
  "../flare-core-examples/apps/flare-core-web-app/src/workbench/app/message-enhancements/components/MessageBatchToolbar.vue",
  "../flare-core-examples/apps/flare-core-tauri-app/src/views",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/message_bubble.dart",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/content_view.dart",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/message_style.dart",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/views",
  "../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/MessageRow/MessageBubbleViews.swift",
  "../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/MessageRow/MessageMediaViews.swift",
  "../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/MessageRow/MessageRichViews.swift",
];

for (const relative of removedUiIslands) {
  const absolute = path.join(root, relative);
  const present = fs.existsSync(absolute)
    && (!fs.statSync(absolute).isDirectory() || fs.readdirSync(absolute).length > 0);
  if (present) {
    failures.push(`${relative}: legacy UI island must stay removed`);
  }
}

const publicDelegates = [
  ["examples/shared/vue-reference/ReferenceApp.vue", ["FlareUiProvider", "provideFlareSdk", "router-view"]],
  ["examples/shared/vue-reference/workbench/app/components/FlareChatWorkspace.vue", ["FlareChatWorkspace", "FlareConversationHeader", "FlareComposer", "FlareMessageList", "FlareMessageBatchToolbar", "FlarePinnedMessageBar"]],
  ["examples/shared/vue-reference/workbench/app/components/FlareWorkbenchLayout.vue", ["WorkbenchShell", "FlareComposerActionPanel", "MessagePreviewModal"]],
  ["examples/shared/vue-reference/workbench/app/components/MessagePreviewModal.vue", ["FlareMessageContentView", "FlareMarkdownPreview"]],
  ["examples/shared/vue-reference/workbench/app/components/ConversationListPanel.vue", ["FlareConversationListContainer", "FlareConversationList", "FlareConversationRow", "FlareScreenHeader"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/shell/workbench_shell.dart", ["FlareIMAppKit"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/conversation_item/conversation_item.dart", ["FlareConversationRow"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/composer/message_composer.dart", ["FlareComposer"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/sdk_message_bubble_adapter.dart", ["FlareMessageBubble", "FlareReactionSummary"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/message/message_long_press_menu.dart", ["FlareMessageActionSheet", "FlareModal"]],
  ["../flare-core-examples/apps/flare-core-flutter-app/lib/interface/widgets/media_viewer/image_preview_modal.dart", ["FlareImagePreview"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/shell/FlareApp.kt", ["IMAppKit"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/messaging/messagerow/MessageRowView.kt", ["MessageBubble", "com.flare.im.ui.MessageActionSheet", "FlareMessageActionAvailability"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/messaging/composer/ComposerView.kt", ["com.flare.im.ui.Composer"]],
  ["../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/messaging/messagerow/MessageContentPrimitives.kt", ["ImagePreview"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Shell/RootWorkbenchView.swift", ["IMAppKitView"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/MessageRow/MessageRowViews.swift", ["MessageBubbleView", "MessageActionSheetView", "FlareMessageActionAvailability", "ReactionSummaryView"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/Composer/ComposerView.swift", ["FlareIMUI.ComposerView"]],
  ["../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging/Media/MediaPreviewSheet.swift", ["ImagePreviewView"]],
];

for (const [relative, symbols] of publicDelegates) {
  const absolute = path.join(root, relative);
  if (!fs.existsSync(absolute)) {
    failures.push(`${relative}: required adapter is missing`);
    continue;
  }
  const source = fs.readFileSync(absolute, "utf8");
  for (const symbol of symbols) {
    if (!source.includes(symbol)) failures.push(`${relative}: must delegate to ${symbol}`);
  }
}

// Message long-press actions: availability comes from the core, the sheet (labels, icons, groups)
// from the kit. An example drawing its own menu or keeping its own copy of the rules is the drift
// this guards against.
const forbiddenExampleSources = [
  [
    "../flare-core-examples/apps/flare-core-android-app/app/src/main/kotlin/com/flare/im/app/features/messaging/messagerow",
    /^import androidx\.compose\.material3\.DropdownMenu\b/m,
    "message actions render through the kit MessageActionSheet, not a Material DropdownMenu",
  ],
  [
    "../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp/Features/Messaging",
    /\bstruct\s+MessageActionSheet\s*:\s*View\b/,
    "message actions render through the kit MessageActionSheetView, not an app-drawn sheet",
  ],
  [
    "../flare-core-examples/apps/flare-core-ios-app/Sources/FlareImApp",
    /\bstruct\s+MessageActionAvailability\b|\bstatic\s+func\s+availability\s*\(/,
    "message action availability is the core's answer, not an app-side copy of the rules",
  ],
];

function sourceFiles(absolute) {
  if (!fs.existsSync(absolute)) return [];
  if (!fs.statSync(absolute).isDirectory()) return [absolute];
  return fs.readdirSync(absolute).flatMap((name) => sourceFiles(path.join(absolute, name)));
}

for (const [relative, pattern, reason] of forbiddenExampleSources) {
  for (const file of sourceFiles(path.join(root, relative))) {
    if (!/\.(kt|swift|dart)$/.test(file)) continue;
    if (pattern.test(fs.readFileSync(file, "utf8"))) {
      failures.push(`${path.relative(root, file)}: ${reason}`);
    }
  }
}

const webChatStyles = fs.readFileSync(
  path.join(root, "examples/shared/vue-reference/workbench/app/styles/routes/chat.css"),
  "utf8",
);
const forbiddenMessageSelectors = [
  ".message-list",
  ".message-row",
  ".message-bubble",
  ".message-content",
  ".message-meta",
  ".message-batch-toolbar",
];
for (const selector of forbiddenMessageSelectors) {
  if (webChatStyles.includes(selector)) {
    failures.push(`flare-core-web-app chat.css: message presentation must stay in the kit (${selector})`);
  }
}

if (failures.length) {
  console.error(`example-no-duplicate-ui failed:\n${failures.map((item) => `- ${item}`).join("\n")}`);
  process.exit(1);
}

console.log("example-no-duplicate-ui passed");
