import { existsSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const sdkRoot = resolve(scriptDir, "../../..");
const repoRoot = resolve(sdkRoot, "..");
const examplesRoot = join(repoRoot, "flare-core-examples");

const scanRoots = [
  "../flare-core-examples/shared/vue-reference",
  "packages/flare-core-apple-sdk/Sources/FlareCoreAppleSDK/Bridge",
  "packages/flare-core-flutter-sdk/lib/src/bridge",
  "../flare-core-examples/apps/flare-core-web-app/src",
  "../flare-core-examples/apps/flare-core-tauri-app/src",
  "../flare-core-examples/apps/flare-core-electron-app/src",
  "../flare-core-examples/apps/flare-core-uni-app/src",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/application",
  "../flare-core-examples/apps/flare-core-flutter-app/lib/interface",
  "../flare-core-examples/apps/flare-core-rn-app/src",
  "../flare-core-examples/apps/flare-core-ios-app/Sources",
];

// 扫描根写死一串相对路径，而仓库拆分后其中若干已经不在本仓（vue-im-ui 迁去
// flare-im-design，部分 example app 各自独立成仓）。原先不过滤，缺一个目录整个
// 门禁就 ENOENT 崩掉 —— 表现是「测试跑不起来」，而不是「有目录缺了」。
// 改为存在才扫，并把跳过的显式打出来，免得门禁悄悄缩水成什么都不查。
const missingScanRoots = scanRoots.filter((rel) => !existsSync(resolve(sdkRoot, rel)));
const presentScanRoots = scanRoots.filter((rel) => existsSync(resolve(sdkRoot, rel)));
if (missingScanRoots.length > 0) {
  console.warn(`[shadow-views] 跳过不存在的扫描根（已拆分到别的仓）：\n  ${missingScanRoots.join("\n  ")}`);
}


const forbiddenIdentifiers = [
  "_mergeConversation",
  "_mergeMessageSnapshot",
  "_patchConversationPreviewFromMessages",
  "applyIncomingMessage",
  "deriveTimelineState",
  "applyIncomingMessages",
  "applyMessagePreview",
  "applyMessageProjection",
  "applyMessageToConversationProjection",
  "applySentMessage",
  "compareConversationsForDisplay",
  "compareTimelineMessages",
  "conversationSortTimestamp",
  "conversationWithMessageProjection",
  "enrichComposerPayloadWithLocalMedia",
  "businessSmoke",
  "createLocalTimelineMessage",
  "createOptimisticText",
  "createOptimisticTextMessage",
  "injectIncoming",
  "applyWasmConversationProjectionForTesting",
  "getMessageContentPreview",
  "latestMessageForConversation",
  "mergeConversationRefreshSnapshot",
  "mergeConversationSnapshot",
  "mergeMessageRefreshSnapshot",
  "mergeMessageSnapshot",
  "mergeTimelineMessage",
  "normalizeTimelineMessagesForDisplay",
  "ingestCoreReceivedBatch",
  "readSeqForConversation",
  "replaceMessageSnapshotByClientId",
  "resolveConversationIdForPeer",
  "prefetchRemote",
  "prefetchRemoteEntry",
  "shouldPreserveLocalTimelineOverlay",
  "_sortConversationsByActivity",
  "_withLocalPendingMessage",
  "_compareMessagesNewestFirst",
  "_messageIdentityForSort",
  "_projectMessageToConversation",
  "_sameTimelineMessage",
  "uniqueMessageIdentityKeys",
  "updateConversationProjection",
  "updateConversationPreviewInSnapshot",
  "upsertActiveTimelineMessage",
  "upsertConversationProjection",
];

const forbiddenPaths = [
  "packages/flare-core-typescript-sdk/src/app",
  "packages/flare-core-typescript-sdk/src/adapters/web/appClient.ts",
  "packages/flare-core-typescript-sdk/src/adapters/web/media/webAppMedia.ts",
  "packages/flare-core-typescript-sdk/src/storage",
  "packages/flare-core-typescript-sdk/src/adapters/web/coreToken.ts",
];

const forbiddenPatterns = [
  {
    name: "lastMessagePreview fallback",
    pattern: /\blastMessagePreview\s*\|\|/,
  },
  {
    name: "conversationId channelId fallback",
    pattern: /\bconversationId\s*\|\|[^\n]*\bchannelId\b/,
  },
  {
    name: "conversation preview derived from lastMessage content",
    pattern: /\blastMessage\?\.content\.previewText\b/,
  },
  {
    name: "message.dispatch operation switch",
    pattern: /\bcase\s+['"]message\.dispatch['"]/,
    pathIncludes: "/bridge/",
  },
  {
    name: "message.typing operation switch",
    pattern: /\bcase\s+['"]message\.typing['"]/,
    pathIncludes: "/bridge/",
  },
  {
    name: "retired media prefetch operation",
    pattern: /\b(prefetch_remote|media\.prefetch_remote)\b/,
  },
  {
    name: "runtime local-only media payload",
    pattern: /\b(remoteUploadStatus|local_only|browser-file-object-url|localFiles)\b/,
    pathIncludes: "packages/vue-im-ui/src/app/message-enhancements/",
  },
  {
    name: "runtime hard-coded login user seed",
    pattern: /\bVITE_FLARE_USER_ID\s*,\s*['"][^'"]+['"]/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "runtime hard-coded SDK Lab data seed",
    pattern: /\b(messageText|peerUserId|userIds|capabilityTargetUserId|downloadKey|displayFileName)\s*:\s*['"][^'"]+['"]/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "client-side conversation resort",
    pattern: /\bconversations\.value\s*=\s*[\s\S]{0,400}\.sort\s*\(/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "client-side timeline normalization",
    pattern: /\bmessages\.value\s*=\s*normalizeTimelineMessagesForDisplay\b/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "conversation list view snapshot resort",
    pattern: /\bapplyConversationListViewSnapshot\b[\s\S]{0,1600}\bsnapshot\.conversations\b[\s\S]{0,800}\.sort\s*\(/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "timeline view snapshot shadow merge",
    pattern: /\bapplyTimelineViewSnapshot\b[\s\S]{0,2200}\b(normalizeTimelineMessagesForDisplay|mergeTimelineMessage|compareTimelineMessages|\.sort\s*\()/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "timeline view delta shadow merge",
    pattern: /\bapplyTimelineViewDelta\b[\s\S]{0,1800}\b(normalizeTimelineMessagesForDisplay|mergeTimelineMessage|compareTimelineMessages|\.sort\s*\()/,
    pathIncludes: "packages/vue-im-ui/src/composables/useflarecoreclient.ts",
  },
  {
    name: "flutter provider conversation resort",
    pattern: /\bstate\s*=\s*[\s\S]{0,500}\.sort\s*\(/,
    pathIncludes: "../flare-core-examples/apps/flare-core-flutter-app/lib/application/providers/conversation_state_provider.dart",
  },
  {
    name: "flutter provider timeline resort",
    pattern: /(\bstate\s*=\s*[\s\S]{0,500}\.sort\s*\(|\breturn\s+\w+\s*\.\.sort\s*\()/,
    pathIncludes: "../flare-core-examples/apps/flare-core-flutter-app/lib/application/providers/message_state_provider.dart",
  },
  {
    name: "flutter conversation preview projection",
    pattern: /\blastMessagePreview\s*:\s*message\.content\.previewText\b/,
    pathIncludes: "../flare-core-examples/apps/flare-core-flutter-app/lib/application/providers/conversation_state_provider.dart",
  },
  {
    name: "capability operation switch",
    pattern: /\bcase\s+['"]capability\.(list|list_user|dispatch|grant|revoke|send_call_signal)['"]/,
    pathIncludes: "/bridge/",
  },
];

const runtimeSeedScanRoots = [
  { base: sdkRoot, rel: "../flare-core-examples/apps/flare-core-flutter-app/lib/interface" },
  { base: sdkRoot, rel: "../flare-core-examples/apps/flare-core-tauri-app/src" },
  { base: sdkRoot, rel: "../flare-core-examples/apps/flare-core-electron-app/src" },
  { base: sdkRoot, rel: "../flare-core-examples/apps/flare-core-uni-app/src" },
  { base: sdkRoot, rel: "../flare-core-examples/apps/flare-core-rn-app/src" },
];

const forbiddenRuntimeSeedPatterns = [
  {
    name: "runtime demo message builder seed",
    pattern:
      /(thread-demo-|vote-demo-|task-demo-|sched-demo-|debug_custom|e2e_pending|wx_debug_appid|picsum\.photos|示例站点|调试地点|调试小程序|通知正文（调试）|公告正文（调试）|线程回复（调试）)/,
  },
  {
    name: "runtime React Native local seed",
    pattern: /(initialConversations|initialMessages|initialUploadTasks|single-me-|rn-demo|local-rich-|local-file-|upload-\d+)/,
  },
  {
    name: "runtime hard-coded sample identity placeholder",
    pattern: /(placeholder\s*=\s*["'][^"']*\b(alice|bob|hugo)\b[^"']*["']|placeholder:\s*["'](?:id1,id2|u1,\s*u2)["'])/i,
  },
];

const forbiddenAssetPatterns = new Map([
  [
    "app_defaults.json",
    [
      {
        name: "runtime hard-coded login user seed",
        pattern: /"userId"\s*:\s*"[^"]+"/,
      },
      {
        name: "runtime hard-coded conversation seed",
        pattern: /"conversationId"\s*:\s*"[^"]+"/,
      },
    ],
  ],
]);

const sharedAssetSources = new Map([
  [
    "emoji-locales.json",
    new Set(["../flare-core-examples/shared/assets/i18n/emoji-locales.json"]),
  ],
  [
    "app_defaults.json",
    new Set([
      "../flare-core-examples/shared/assets/config/app_defaults.json",
      "../flare-core-examples/apps/flare-core-flutter-app/assets/config/app_defaults.json",
    ]),
  ],
]);

const allowedExtensions = new Set([".dart", ".swift", ".ts", ".tsx", ".vue"]);

function hasAllowedExtension(file) {
  return [...allowedExtensions].some((extension) => file.endsWith(extension));
}

function findMatchingBrace(source, openIndex) {
  let depth = 0;
  for (let index = openIndex; index < source.length; index += 1) {
    const ch = source[index];
    if (ch === "{") {
      depth += 1;
    } else if (ch === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  return -1;
}

function extractFunctionBody(source, functionName) {
  const pattern = new RegExp(`\\bfunction\\s+${functionName}\\s*\\(`, "g");
  const bodies = [];
  let match;
  while ((match = pattern.exec(source)) !== null) {
    const openIndex = source.indexOf("{", match.index);
    if (openIndex < 0) continue;
    const closeIndex = findMatchingBrace(source, openIndex);
    if (closeIndex < 0) continue;
    bodies.push(source.slice(openIndex + 1, closeIndex));
  }
  return bodies;
}

const structuralViewRules = [
  {
    functionName: "applyConversationListViewSnapshot",
    forbidden: [
      {
        name: "conversation list snapshot resort",
        pattern: /\.sort\s*\(/,
      },
      {
        name: "conversation list snapshot shadow projection",
        pattern: /\b(conversationWithMessageProjection|mergeConversationSnapshot|mergeConversationRefreshSnapshot|updateConversationProjection|upsertConversationProjection)\b/,
      },
    ],
  },
  {
    functionName: "applyConversationListViewDelta",
    forbidden: [
      {
        name: "conversation list delta resort",
        pattern: /\.sort\s*\(/,
      },
      {
        name: "conversation list delta shadow projection",
        pattern: /\b(conversationWithMessageProjection|mergeConversationSnapshot|mergeConversationRefreshSnapshot|updateConversationProjection|upsertConversationProjection)\b/,
      },
    ],
  },
  {
    functionName: "applyTimelineViewSnapshot",
    forbidden: [
      {
        name: "timeline snapshot shadow merge",
        pattern: /\b(normalizeTimelineMessagesForDisplay|mergeTimelineMessage|compareTimelineMessages|shouldPreserveLocalTimelineOverlay|uniqueMessageIdentityKeys)\b/,
      },
      {
        name: "timeline snapshot resort",
        pattern: /\.sort\s*\(/,
      },
    ],
  },
  {
    functionName: "applyTimelineViewDelta",
    forbidden: [
      {
        name: "timeline delta shadow merge",
        pattern: /\b(normalizeTimelineMessagesForDisplay|mergeTimelineMessage|compareTimelineMessages|shouldPreserveLocalTimelineOverlay|uniqueMessageIdentityKeys)\b/,
      },
      {
        name: "timeline delta resort",
        pattern: /\.sort\s*\(/,
      },
    ],
  },
];

function collectStructuralViewViolations(relFile, source) {
  const found = [];
  for (const rule of structuralViewRules) {
    for (const body of extractFunctionBody(source, rule.functionName)) {
      for (const { name, pattern } of rule.forbidden) {
        if (pattern.test(body)) {
          found.push(`${relFile}: ${rule.functionName}: ${name}`);
        }
      }
    }
  }
  return found;
}

// 构建产物不是源码：Xcode 派生数据（.build-xcode / DerivedData）里会出现
// kit 资源包的副本，扫到它们会把「共享资源必须走正源」误报成缺陷。
const SKIPPED_DIRECTORIES = new Set([
  "node_modules", "dist", "build", ".build", ".build-xcode", "DerivedData", ".dart_tool", ".cxx",
]);

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (SKIPPED_DIRECTORIES.has(entry.name)) continue;
      files.push(...await walk(path));
      continue;
    }
    if (entry.isFile() && hasAllowedExtension(path)) {
      files.push(path);
    }
  }
  return files;
}

async function walkNamedFiles(directory, names) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (SKIPPED_DIRECTORIES.has(entry.name)) continue;
      if (directory === join(sdkRoot, "examples")
          && /^flare-core-(web|tauri|flutter|android|ios)-app$/.test(entry.name)) continue;
      files.push(...await walkNamedFiles(path, names));
      continue;
    }
    if (entry.isFile() && names.has(entry.name)) {
      files.push(path);
    }
  }
  return files;
}

const violations = [];

for (const rel of forbiddenPaths) {
  try {
    await readdir(join(sdkRoot, rel));
    violations.push(`${rel}: retired shadow implementation path exists`);
  } catch (error) {
    if (error?.code !== "ENOENT" && error?.code !== "ENOTDIR") {
      throw error;
    }
    try {
      await readFile(join(sdkRoot, rel), "utf8");
      violations.push(`${rel}: retired shadow implementation file exists`);
    } catch (fileError) {
      if (fileError?.code !== "ENOENT" && fileError?.code !== "EISDIR") {
        throw fileError;
      }
    }
  }
}

for (const root of presentScanRoots) {
  const files = await walk(join(sdkRoot, root));
  for (const file of files) {
    const source = await readFile(file, "utf8");
    for (const identifier of forbiddenIdentifiers) {
      const pattern = new RegExp(`\\b${identifier}\\b`, "g");
      if (pattern.test(source)) {
        violations.push(`${file.replace(`${sdkRoot}/`, "")}: ${identifier}`);
      }
    }
    const relFile = relative(sdkRoot, file);
    const normalizedRelFile = relFile.toLowerCase();
    for (const { name, pattern, pathIncludes } of forbiddenPatterns) {
      if (pathIncludes && !normalizedRelFile.includes(pathIncludes)) {
        continue;
      }
      if (pattern.test(source)) {
        violations.push(`${relFile}: ${name}`);
      }
    }
    violations.push(...collectStructuralViewViolations(relFile, source));
  }
}

for (const { base, rel } of runtimeSeedScanRoots.filter(({ base, rel }) => existsSync(resolve(base, rel)))) {
  let files = [];
  try {
    files = await walk(join(base, rel));
  } catch (error) {
    if (error?.code === "ENOENT" || error?.code === "ENOTDIR") {
      continue;
    }
    throw error;
  }
  for (const file of files) {
    const source = await readFile(file, "utf8");
    const relFile = file.replace(`${repoRoot}/`, "");
    for (const { name, pattern } of forbiddenRuntimeSeedPatterns) {
      if (pattern.test(source)) {
        violations.push(`${relFile}: ${name}`);
      }
    }
  }
}

const assetNames = new Set(sharedAssetSources.keys());
const assetFiles = await walkNamedFiles(sdkRoot, assetNames);
if (existsSync(examplesRoot)) assetFiles.push(...await walkNamedFiles(examplesRoot, assetNames));
for (const file of assetFiles) {
  const relFile = relative(sdkRoot, file);
  const allowed = sharedAssetSources.get(relFile.split("/").at(-1));
  if (allowed && !allowed.has(relFile)) {
    violations.push(`${relFile}: shared data asset must use the canonical source`);
  }
  const assetPatterns = forbiddenAssetPatterns.get(relFile.split("/").at(-1));
  if (assetPatterns) {
    const source = await readFile(file, "utf8");
    for (const { name, pattern } of assetPatterns) {
      if (pattern.test(source)) {
        violations.push(`${relFile}: ${name}`);
      }
    }
  }
}

if (violations.length > 0) {
  console.error("Client shadow timeline/view helpers are not allowed:");
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log("No client shadow timeline/view helpers found.");
