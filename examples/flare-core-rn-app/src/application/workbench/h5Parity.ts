export const RN_WORKBENCH_STAGES = ['login', 'sync', 'conversations', 'chat', 'sdk'] as const;

export type RnWorkbenchStage = (typeof RN_WORKBENCH_STAGES)[number];

export const RN_CONVERSATION_ACTIONS = [
  'mark_read',
  'mark_unread',
  'pin',
  'unpin',
  'mute',
  'unmute',
  'archive',
  'unarchive',
  'clear_history',
  'draft',
  'delete',
] as const;

export type RnConversationAction = (typeof RN_CONVERSATION_ACTIONS)[number];

export const RN_SDK_LAB_TABS = [
  'diagnostics',
  'connection-session',
  'builder',
  'message-dispatch',
  'sync-presence',
  'capability',
  'media',
  'events',
] as const;

export type RnSdkLabTab = (typeof RN_SDK_LAB_TABS)[number];

export const RN_MESSAGE_DISPATCH_OPERATIONS = [
  'search',
  'search_in_conversation',
  'get',
  'get_raw',
  'edit_text_by_message_id',
  'edit_rich_doc_by_message_id',
  'delete_for_self',
  'delete_for_everyone',
  'add_reaction',
  'remove_reaction',
  'pin_by_message_id',
  'unpin_by_message_id',
  'mark_by_message_id',
  'mark_with_color',
  'unmark_by_message_id',
  'typing',
  'mark_read',
  'mark_read_and_burn',
] as const;

export type RnMessageDispatchOperation = (typeof RN_MESSAGE_DISPATCH_OPERATIONS)[number];

export const RN_MEDIA_LAB_OPERATIONS = [
  'stats',
  'upload_file',
  'upload_image',
  'upload_video',
  'upload_bytes',
  'delete_file',
  'url',
  'temp_url',
  'resolve',
  'display_url',
  'cache_remote',
  'set_root',
  'set_max',
  'download_subfolder',
  'download_file',
  'cancel_download',
  'saved_path',
  'delete_download',
  'clear',
] as const;

export type RnMediaLabOperation = (typeof RN_MEDIA_LAB_OPERATIONS)[number];

export const RN_CAPABILITY_OPERATIONS = [
  'list',
  'dispatch',
] as const;

export type RnCapabilityOperation = (typeof RN_CAPABILITY_OPERATIONS)[number];

// Network and foreground reports are not lab operations: the SDK's platform lifecycle owns them.
export const RN_CONNECTION_OPERATIONS = [
  'status',
  'reconnect_now',
  'disconnect',
  'access_status',
  'access_points',
  'access_diagnostics',
] as const;
export type RnConnectionOperation = (typeof RN_CONNECTION_OPERATIONS)[number];

export const RN_SESSION_OPERATIONS = [
  'current_user',
  'session_active',
  'runtime_health',
  'heartbeat_interval',
  'heartbeat_nat_timeout',
  'update_access_token',
] as const;

export type RnSessionOperation = (typeof RN_SESSION_OPERATIONS)[number];

export type RnRouteGateState = {
  loggedIn: boolean;
  homeSyncReady: boolean;
};

export function shouldShowLogin(state: RnRouteGateState): boolean {
  return !state.loggedIn;
}

export function shouldShowSync(state: RnRouteGateState): boolean {
  return state.loggedIn && !state.homeSyncReady;
}
