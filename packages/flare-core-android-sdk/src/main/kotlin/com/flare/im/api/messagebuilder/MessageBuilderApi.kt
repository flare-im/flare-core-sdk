package com.flare.im.api.messagebuilder

import com.flare.im.callback.*
import com.flare.im.listener.*
import com.flare.im.model.catalog.*
import com.flare.im.model.command.*
import com.flare.im.model.command.message.*
import com.flare.im.model.command.message.build.*
import com.flare.im.model.common.enums.*
import com.flare.im.model.common.error.*
import com.flare.im.model.content.*
import com.flare.im.model.entity.*
import com.flare.im.model.event.*
import com.flare.im.model.event.access.*
import com.flare.im.model.event.connection.*
import com.flare.im.model.event.conversation.*
import com.flare.im.model.event.lifecycle.*
import com.flare.im.model.event.message.*
import com.flare.im.model.event.plugin.*
import com.flare.im.model.event.presence.*
import com.flare.im.model.event.progress.*
import com.flare.im.model.event.sync.*
import com.flare.im.model.media.*
import com.flare.im.model.query.*
import com.flare.im.model.response.*

/** GENERATED. Do not edit by hand. */
/** Typed quick-build APIs for all supported message content kinds. Prefer these over raw JSON in adapters. */
interface MessageBuilderApi {
    /** listSupportedBuildOperations maps to `flare_message_build_json` via `catalog-static`. Operation: `message_builder.list_catalog`. */
    suspend fun listSupportedBuildOperations(): ListMessageBuildCatalogResponse
    /** normalizeRichDocFromMarkdown maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_markdown`. */
    suspend fun normalizeRichDocFromMarkdown(request: NormalizeRichDocFromMarkdownRequest): RichDocV2Normalized
    /** normalizeRichDocFromHtml maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_html`. */
    suspend fun normalizeRichDocFromHtml(request: NormalizeRichDocFromHtmlRequest): RichDocV2Normalized
    /** normalizeRichDocFromDocJson maps to `flare_sdk_invoke_json` via `contract-invoke-json`. Operation: `rich_doc_v2.normalize_from_doc_json`. */
    suspend fun normalizeRichDocFromDocJson(request: NormalizeRichDocFromDocJsonRequest): RichDocV2Normalized
    /** buildAnnouncement maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_announcement`. Operation: `message_builder.create_announcement`. */
    suspend fun buildAnnouncement(request: BuildAnnouncementMessageRequest): Message
    /** buildAudio maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_audio`. Operation: `message_builder.create_audio`. */
    suspend fun buildAudio(request: BuildAudioMessageRequest): Message
    /** buildCard maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_card`. Operation: `message_builder.create_card`. */
    suspend fun buildCard(request: BuildCardMessageRequest): Message
    /** buildCustom maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_custom`. Operation: `message_builder.create_custom`. */
    suspend fun buildCustom(request: BuildCustomMessageRequest): Message
    /** buildEmoji maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_emoji`. Operation: `message_builder.create_emoji`. */
    suspend fun buildEmoji(request: BuildEmojiMessageRequest): Message
    /** buildFile maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_file`. Operation: `message_builder.create_file`. */
    suspend fun buildFile(request: BuildFileMessageRequest): Message
    /** buildForward maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_forward`. Operation: `message_builder.create_forward`. */
    suspend fun buildForward(request: BuildForwardMessageRequest): Message
    /** buildImage maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_image`. Operation: `message_builder.create_image`. */
    suspend fun buildImage(request: BuildImageMessageRequest): Message
    /** buildImageGroup maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_image_group`. Operation: `message_builder.create_image_group`. */
    suspend fun buildImageGroup(request: BuildImageGroupMessageRequest): Message
    /** buildLinkCard maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_link_card`. Operation: `message_builder.create_link_card`. */
    suspend fun buildLinkCard(request: BuildLinkCardMessageRequest): Message
    /** buildLocation maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_location`. Operation: `message_builder.create_location`. */
    suspend fun buildLocation(request: BuildLocationMessageRequest): Message
    /** buildMiniProgram maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_mini_program`. Operation: `message_builder.create_mini_program`. */
    suspend fun buildMiniProgram(request: BuildMiniProgramMessageRequest): Message
    /** buildNotification maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_notification`. Operation: `message_builder.create_notification`. */
    suspend fun buildNotification(request: BuildNotificationMessageRequest): Message
    /** buildPlaceholder maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_placeholder`. Operation: `message_builder.create_placeholder`. */
    suspend fun buildPlaceholder(request: BuildPlaceholderMessageRequest): Message
    /** buildQuote maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_quote`. Operation: `message_builder.create_quote`. */
    suspend fun buildQuote(request: BuildQuoteMessageRequest): Message
    /** buildRichDoc maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_rich_doc`. Operation: `message_builder.create_rich_doc`. */
    suspend fun buildRichDoc(request: BuildRichDocMessageRequest): Message
    /** buildSchedule maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_schedule`. Operation: `message_builder.create_schedule`. */
    suspend fun buildSchedule(request: BuildScheduleMessageRequest): Message
    /** buildSticker maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_sticker`. Operation: `message_builder.create_sticker`. */
    suspend fun buildSticker(request: BuildStickerMessageRequest): Message
    /** buildSystem maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_system`. Operation: `message_builder.create_system`. */
    suspend fun buildSystem(request: BuildSystemMessageRequest): Message
    /** buildTask maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_task`. Operation: `message_builder.create_task`. */
    suspend fun buildTask(request: BuildTaskMessageRequest): Message
    /** buildText maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_text`. Operation: `message_builder.create_text`. */
    suspend fun buildText(request: BuildTextMessageRequest): Message
    /** buildThreadReply maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_thread_reply`. Operation: `message_builder.create_thread_reply`. */
    suspend fun buildThreadReply(request: BuildThreadReplyMessageRequest): Message
    /** buildVideo maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_video`. Operation: `message_builder.create_video`. */
    suspend fun buildVideo(request: BuildVideoMessageRequest): Message
    /** buildVote maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_vote`. Operation: `message_builder.create_vote`. */
    suspend fun buildVote(request: BuildVoteMessageRequest): Message
    /** buildWithContent maps to `flare_message_build_json` via `dispatch-json`, dispatch op `create_with_content`. Operation: `message_builder.create_with_content`. */
    suspend fun buildWithContent(request: BuildWithContentMessageRequest): Message
}
