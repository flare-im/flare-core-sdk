// Shared Flare IM Vue workbench building blocks.
// Platform example apps own their App.vue, router, route guards, and page
// registration. This package exposes reusable views, layouts, state, and
// platform adapter hooks so each runtime can assemble its own shell.
export { default as FlareWorkbenchLayout } from "./components/FlareWorkbenchLayout.vue";
export { default as FlareLoginScreen } from "./components/FlareLoginScreen.vue";
export { default as FlareHomeSyncScreen } from "./components/FlareHomeSyncScreen.vue";
export { default as FlareConversationsPanel } from "./components/FlareConversationsPanel.vue";
export { default as FlareChatPlaceholder } from "./components/FlareChatPlaceholder.vue";
export { default as FlareChatWorkspace } from "./components/FlareChatWorkspace.vue";
export { default as FlareSdkLabPanel } from "./components/FlareSdkLabPanel.vue";
export { default as FlareAccessDiagnosticsScreen } from "./components/FlareAccessDiagnosticsScreen.vue";
export { default as FlareAboutScreen } from "./components/FlareAboutScreen.vue";
export { default as FlareUpdatePromptHost } from "./components/FlareUpdatePromptHost.vue";
export { provideFlareUpdates, useFlareUpdates, type FlareUpdates } from "./state/update";
export { pendingRecoveryLink } from "./state/accessDiagnostics";
export {
  getFlareSdkSingleton,
  provideFlareSdk,
  useFlareSdk,
  type FlareSdkContext,
} from "./sdk/flareSdkContext";
export * from "./ui/components";
export {
  useConversationListModel,
} from "./state/useConversationListModel";
export { useFlareI18n, type FlareLocale } from "./shared/i18n";
export {
  conversationTitle,
  resolveConversationPeer,
} from "./shared/conversationTitle";
export { locateTimelineMessage } from "./shared/locateTimelineMessage";
export { DraftIdleScheduler } from "./shared/draftIdleScheduler";
export {
  createMessageOperationAdapter,
} from "./message-enhancements/messageOperations";
export {
  resolveComposerAction,
  resolveMessageMenuActions,
  type ComposerActionDefinition,
} from "./message-enhancements/messageTypeRegistry";
export {
  useMessageInteractionState,
} from "./message-enhancements/useMessageInteractionState";
export {
  default as FlareComposerPayloadModal,
} from "./message-enhancements/components/ComposerPayloadModal.vue";
export {
  default as FlareForwardModal,
} from "./message-enhancements/components/ForwardModal.vue";
export {
  FlareComposerMediaPreview,
} from "@flare-im/vue-ui/components";
export type {
  BatchOperationResult,
  ComposerPayloadRequest,
  EnhancedMessageKind,
  ForwardMode,
  MediaComposerPreviewItem,
  MessageOperationSdk,
  MessagePinScope,
} from "./message-enhancements/types";
export {
  createProductionAppClient,
  configureProductionAppClientFactory,
  configureProductionAppHost,
  productionAppHost,
  type ProductionAppClientFactory,
  type ProductionAppHost,
} from "./infrastructure/sdk/createProductionAppClient";
export {
  configureAppMediaLocalPathResolver,
  createAppMediaResolver,
  resolveAppMediaLocalPath,
} from "./infrastructure/media/appMediaResolver";
export { configureAppPlatform, appPlatformOptions } from "./infrastructure/platform/appPlatform";
export {
  canRevealDownloadedMedia,
  configureNativeMediaActions,
  revealDownloadedMediaFile,
  startBrowserDownload,
} from "./infrastructure/media/downloadedMediaActions";
export {
  configureDownloadDirectoryPicker,
  loadDownloadLocation,
  mediaCacheBytes,
  pickDownloadLocation,
  resetDownloadLocation,
  type DownloadDirectoryPicker,
  type DownloadLocation,
} from "./infrastructure/media/downloadLocation";
export {
  playDesktopNotificationSound,
  type DesktopNotificationKind,
} from "./infrastructure/desktop/desktopNotifications";
export {
  createNotificationPermission,
  provideNotificationPermission,
  useNotificationPermission,
  type NotificationPermission,
} from "./infrastructure/notifications/notificationPermission";
export { sdkMediaProxyFields } from "./runtime/mediaProxy";

export { messageSearchRange, messageSearchRangeLabels, type MessageSearchRangePreset } from "./shared/messageSearchRanges";
