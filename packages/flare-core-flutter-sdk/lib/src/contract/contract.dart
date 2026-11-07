// GENERATED. Do not edit by hand.
const String kFlareFfiContractVersion = 'flare-im-ffi/v2';

abstract final class SdkOperations {
  const SdkOperations._();
  static const String sdkCreate = 'sdk.create';
  static const String sdkInit = 'sdk.init';
  static const String sdkUninit = 'sdk.uninit';
  static const String sdkLogin = 'sdk.login';
  static const String sdkPrepare = 'sdk.prepare';
  static const String sdkConnect = 'sdk.connect';
  static const String sdkUpdateAccessToken = 'sdk.update_access_token';
  static const String sdkSetConnectTokenRefresher = 'sdk.set_connect_token_refresher';
  static const String sdkCompleteConnectTokenRefresh = 'sdk.complete_connect_token_refresh';
  static const String sdkSetHeartbeatNatTimeout =
      'sdk.set_heartbeat_nat_timeout';
  static const String sdkHeartbeatEffectiveInterval =
      'sdk.heartbeat_effective_interval';
  static const String sdkLogout = 'sdk.logout';
  static const String sdkDispose = 'sdk.dispose';
  static const String sdkHardReset = 'sdk.hard_reset';
  static const String sdkCurrentUserId = 'sdk.current_user_id';
  static const String sdkIsConnected = 'sdk.is_connected';
  static const String sdkSessionActive = 'sdk.session_active';
  static const String connectionGetStatus = 'connection.get_status';
  static const String connectionReconnectNow = 'connection.reconnect_now';
  static const String accessGetStatus = 'access.get_status';
  static const String accessListAccessPoints = 'access.list_access_points';
  static const String accessPin = 'access.pin';
  static const String accessUnpin = 'access.unpin';
  static const String accessRefresh = 'access.refresh';
  static const String accessImportRecovery = 'access.import_recovery';
  static const String accessExportDiagnostics = 'access.export_diagnostics';
  static const String updateGetState = 'update.get_state';
  static const String updateCheck = 'update.check';
  static const String updateDownload = 'update.download';
  static const String updateInstall = 'update.install';
  static const String updateReportInstall = 'update.report_install';
  static const String updateDefer = 'update.defer';
  static const String updateSkip = 'update.skip';
  static const String updateMarkPrompted = 'update.mark_prompted';
  static const String updateSetLocale = 'update.set_locale';
  static const String updateGetResources = 'update.get_resources';
  static const String lifecycleSetAppState = 'lifecycle.set_app_state';
  static const String connectionDisconnect = 'connection.disconnect';
  static const String conversationList = 'conversation.list';
  static const String conversationListByQuery = 'conversation.list_by_query';
  static const String conversationListIncludingArchived =
      'conversation.list_including_archived';
  static const String conversationGet = 'conversation.get';
  static const String conversationGetOne = 'conversation.get_one';
  static const String conversationGetGroupByUserIds =
      'conversation.get_group_by_user_ids';
  static const String conversationGetMultiple = 'conversation.get_multiple';
  static const String conversationListPaginated = 'conversation.list_paginated';
  static const String conversationListRaw = 'conversation.list_raw';
  static const String conversationBootstrapHome = 'conversation.bootstrap_home';
  static const String conversationOpenTimeline = 'conversation.open_timeline';
  static const String conversationMarkRead = 'conversation.mark_read';
  static const String conversationSetPinned = 'conversation.set_pinned';
  static const String conversationSetMuted = 'conversation.set_muted';
  static const String conversationSetArchived = 'conversation.set_archived';
  static const String conversationMarkUnread = 'conversation.mark_unread';
  static const String conversationDelete = 'conversation.delete';
  static const String conversationUpdateDraft = 'conversation.update_draft';
  static const String conversationClearLocalChatHistory =
      'conversation.clear_local_chat_history';
  static const String messageBuilderListCatalog =
      'message_builder.list_catalog';
  static const String richDocV2NormalizeFromMarkdown =
      'rich_doc_v2.normalize_from_markdown';
  static const String richDocV2NormalizeFromHtml =
      'rich_doc_v2.normalize_from_html';
  static const String richDocV2NormalizeFromDocJson =
      'rich_doc_v2.normalize_from_doc_json';
  static const String messageBuilderCreateAnnouncement =
      'message_builder.create_announcement';
  static const String messageBuilderCreateAudio =
      'message_builder.create_audio';
  static const String messageBuilderCreateCard = 'message_builder.create_card';
  static const String messageBuilderCreateCustom =
      'message_builder.create_custom';
  static const String messageBuilderCreateEmoji =
      'message_builder.create_emoji';
  static const String messageBuilderCreateFile = 'message_builder.create_file';
  static const String messageBuilderCreateForward =
      'message_builder.create_forward';
  static const String messageBuilderCreateImage =
      'message_builder.create_image';
  static const String messageBuilderCreateImageGroup =
      'message_builder.create_image_group';
  static const String messageBuilderCreateLinkCard =
      'message_builder.create_link_card';
  static const String messageBuilderCreateLocation =
      'message_builder.create_location';
  static const String messageBuilderCreateMiniProgram =
      'message_builder.create_mini_program';
  static const String messageBuilderCreateNotification =
      'message_builder.create_notification';
  static const String messageBuilderCreatePlaceholder =
      'message_builder.create_placeholder';
  static const String messageBuilderCreateQuote =
      'message_builder.create_quote';
  static const String messageBuilderCreateRichDoc =
      'message_builder.create_rich_doc';
  static const String messageBuilderCreateSchedule =
      'message_builder.create_schedule';
  static const String messageBuilderCreateSticker =
      'message_builder.create_sticker';
  static const String messageBuilderCreateSystem =
      'message_builder.create_system';
  static const String messageBuilderCreateTask = 'message_builder.create_task';
  static const String messageBuilderCreateText = 'message_builder.create_text';
  static const String messageBuilderCreateThreadReply =
      'message_builder.create_thread_reply';
  static const String messageBuilderCreateVideo =
      'message_builder.create_video';
  static const String messageBuilderCreateVote = 'message_builder.create_vote';
  static const String messageBuilderCreateWithContent =
      'message_builder.create_with_content';
  static const String messageCreateText = 'message.create_text';
  static const String messageDispatch = 'message.dispatch';
  static const String messageSendNoOss = 'message.send_no_oss';
  static const String messageSend = 'message.send';
  static const String messageList = 'message.list';
  static const String messageRecall = 'message.recall';
  static const String messageEditTextByMessageId =
      'message.edit_text_by_message_id';
  static const String messageDelete = 'message.delete';
  static const String messageDeleteForSelf = 'message.delete_for_self';
  static const String messageDeleteForEveryone = 'message.delete_for_everyone';
  static const String messageMarkReadAndBurn = 'message.mark_read_and_burn';
  static const String messageAddReaction = 'message.add_reaction';
  static const String messageRemoveReaction = 'message.remove_reaction';
  static const String messagePin = 'message.pin';
  static const String messageUnpin = 'message.unpin';
  static const String messagePinByMessageId = 'message.pin_by_message_id';
  static const String messageUnpinByMessageId = 'message.unpin_by_message_id';
  static const String messageMark = 'message.mark';
  static const String messageMarkWithColor = 'message.mark_with_color';
  static const String messageUnmark = 'message.unmark';
  static const String messageMarkByMessageId = 'message.mark_by_message_id';
  static const String messageUnmarkByMessageId = 'message.unmark_by_message_id';
  static const String messageGet = 'message.get';
  static const String messageGetRaw = 'message.get_raw';
  static const String messageSearch = 'message.search';
  static const String messageSearchByQuery = 'message.search_by_query';
  static const String messageSearchInConversation =
      'message.search_by_query';
  static const String messageEditRichDocByMessageId =
      'message.edit_rich_doc_by_message_id';
  static const String messageTyping = 'message.typing';
  static const String syncConversationSummaries = 'sync.conversation_summaries';
  static const String syncConversationSummariesWithVersions =
      'sync.conversation_summaries_with_versions';
  static const String syncConversation = 'sync.conversation';
  static const String syncMessages = 'sync.messages';
  static const String presenceGet = 'presence.get';
  static const String presenceBatchGet = 'presence.batch_get';
  static const String presenceSubscribe = 'presence.subscribe';
  static const String mediaUploadFile = 'media.upload_file';
  static const String mediaUploadImage = 'media.upload_image';
  static const String mediaUploadVideo = 'media.upload_video';
  static const String mediaUploadBytes = 'media.upload_bytes';
  static const String mediaDeleteFile = 'media.delete_file';
  static const String mediaGetUrl = 'media.get_url';
  static const String mediaTempDownloadUrl = 'media.temp_download_url';
  static const String mediaResolveAccess = 'media.resolve_access';
  static const String mediaCacheRemote = 'media.cache_remote';
  static const String mediaCacheStats = 'media.cache_stats';
  static const String mediaSetCacheMaxBytes = 'media.set_cache_max_bytes';
  static const String mediaSetCacheRoot = 'media.set_cache_root';
  static const String mediaClearCache = 'media.clear_cache';
  static const String mediaUserDownloadGetSubfolder =
      'media.user_download_get_subfolder';
  static const String mediaUserDownloadSetSubfolder =
      'media.user_download_set_subfolder';
  static const String mediaUserDownloadGetSavedPath =
      'media.user_download_get_saved_path';
  static const String mediaUserDownloadDeleteRecord =
      'media.user_download_delete_record';
  static const String mediaCancelUserFileDownload =
      'media.cancel_user_file_download';
  static const String mediaDownloadFileToDownloads =
      'media.download_file_to_downloads';
  static const String capabilityList = 'capability.list';
  static const String capabilityListUser = 'capability.list_user';
  static const String capabilityDispatch = 'capability.dispatch';
  static const String capabilityGrant = 'capability.grant';
  static const String capabilityRevoke = 'capability.revoke';
  static const String eventSubscribe = 'event.subscribe';
  static const String eventSubscribeBatch = 'event.subscribe_batch';
  static const String eventUnsubscribe = 'event.unsubscribe';
  static const String eventUnsubscribeAll = 'event.unsubscribe_all';
  static const String diagnosticsSdkVersion = 'diagnostics.sdk_version';
  static const String diagnosticsFfiContractVersion =
      'diagnostics.ffi_contract_version';
  static const String diagnosticsDataRoot = 'diagnostics.data_root';
}

abstract final class SdkErrorCodes {
  const SdkErrorCodes._();
  static const String invalidParameter = 'invalidParameter';
  static const String notInitialized = 'notInitialized';
  static const String notConnected = 'notConnected';
  static const String unauthorized = 'unauthorized';
  static const String permissionDenied = 'permissionDenied';
  static const String timeout = 'timeout';
  static const String networkUnavailable = 'networkUnavailable';
  static const String storageUnavailable = 'storageUnavailable';
  static const String operationCancelled = 'operationCancelled';
  static const String capabilityUnavailable = 'capabilityUnavailable';
  static const String overloaded = 'overloaded';
  static const String upgradeRequired = 'upgradeRequired';
  static const String networkUncertain = 'networkUncertain';
  static const String internal = 'internal';
}
