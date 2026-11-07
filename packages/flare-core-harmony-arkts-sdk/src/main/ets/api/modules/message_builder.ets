// GENERATED. Do not edit by hand.
import { AccessChangedEvent, AccessSwitchedEvent, BuildAnnouncementMessageRequest, BuildAudioMessageRequest, BuildCardMessageRequest, BuildCustomMessageRequest, BuildEmojiMessageRequest, BuildFileMessageRequest, BuildForwardMessageRequest, BuildImageGroupMessageRequest, BuildImageMessageRequest, BuildLinkCardMessageRequest, BuildLocationMessageRequest, BuildMiniProgramMessageRequest, BuildNotificationMessageRequest, BuildPlaceholderMessageRequest, BuildQuoteMessageRequest, BuildRichDocMessageRequest, BuildScheduleMessageRequest, BuildStickerMessageRequest, BuildSystemMessageRequest, BuildTaskMessageRequest, BuildTextMessageRequest, BuildThreadReplyMessageRequest, BuildVideoMessageRequest, BuildVoteMessageRequest, BuildWithContentMessageRequest, ConnectionStatus, ConversationEvent, LifecycleEvent, ListMessageBuildCatalogResponse, Message, MessageMutationEvent, MessageReceivedBatchEvent, MessageReceivedEvent, MessageSendAckEvent, MessageSendFailedEvent, NormalizeRichDocFromDocJsonRequest, NormalizeRichDocFromHtmlRequest, NormalizeRichDocFromMarkdownRequest, PluginCatalogChangedEvent, PluginRealtimeEvent, ProgressEvent, ReactionChangedEvent, ReadReceiptEvent, RichDocV2Normalized, SyncEvent, TypingAggregateEvent, TypingEvent, UpdateStatus, ViewUpdate } from '../../model';

/** Typed quick-build APIs for all supported message content kinds. Prefer these over raw JSON in adapters. */
export interface MessageBuilderApi {
  listSupportedBuildOperations(): Promise<ListMessageBuildCatalogResponse>;
  normalizeRichDocFromMarkdown(request: NormalizeRichDocFromMarkdownRequest): Promise<RichDocV2Normalized>;
  normalizeRichDocFromHtml(request: NormalizeRichDocFromHtmlRequest): Promise<RichDocV2Normalized>;
  normalizeRichDocFromDocJson(request: NormalizeRichDocFromDocJsonRequest): Promise<RichDocV2Normalized>;
  buildAnnouncement(request: BuildAnnouncementMessageRequest): Promise<Message>;
  buildAudio(request: BuildAudioMessageRequest): Promise<Message>;
  buildCard(request: BuildCardMessageRequest): Promise<Message>;
  buildCustom(request: BuildCustomMessageRequest): Promise<Message>;
  buildEmoji(request: BuildEmojiMessageRequest): Promise<Message>;
  buildFile(request: BuildFileMessageRequest): Promise<Message>;
  buildForward(request: BuildForwardMessageRequest): Promise<Message>;
  buildImage(request: BuildImageMessageRequest): Promise<Message>;
  buildImageGroup(request: BuildImageGroupMessageRequest): Promise<Message>;
  buildLinkCard(request: BuildLinkCardMessageRequest): Promise<Message>;
  buildLocation(request: BuildLocationMessageRequest): Promise<Message>;
  buildMiniProgram(request: BuildMiniProgramMessageRequest): Promise<Message>;
  buildNotification(request: BuildNotificationMessageRequest): Promise<Message>;
  buildPlaceholder(request: BuildPlaceholderMessageRequest): Promise<Message>;
  buildQuote(request: BuildQuoteMessageRequest): Promise<Message>;
  buildRichDoc(request: BuildRichDocMessageRequest): Promise<Message>;
  buildSchedule(request: BuildScheduleMessageRequest): Promise<Message>;
  buildSticker(request: BuildStickerMessageRequest): Promise<Message>;
  buildSystem(request: BuildSystemMessageRequest): Promise<Message>;
  buildTask(request: BuildTaskMessageRequest): Promise<Message>;
  buildText(request: BuildTextMessageRequest): Promise<Message>;
  buildThreadReply(request: BuildThreadReplyMessageRequest): Promise<Message>;
  buildVideo(request: BuildVideoMessageRequest): Promise<Message>;
  buildVote(request: BuildVoteMessageRequest): Promise<Message>;
  buildWithContent(request: BuildWithContentMessageRequest): Promise<Message>;
}
