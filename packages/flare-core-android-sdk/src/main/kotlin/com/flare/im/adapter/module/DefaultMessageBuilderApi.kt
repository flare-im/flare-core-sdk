package com.flare.im.adapter.module

import com.flare.im.adapter.codec.*
import com.flare.im.api.messagebuilder.MessageBuilderApi
import com.flare.im.callback.*
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallMap
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
class DefaultMessageBuilderApi(
    private val bridge: NativeBridge,
) : MessageBuilderApi {

    override suspend fun listSupportedBuildOperations(): ListMessageBuildCatalogResponse {
        return ListMessageBuildCatalogResponse(entries = MESSAGE_BUILD_CATALOG)
    }

    override suspend fun normalizeRichDocFromMarkdown(request: NormalizeRichDocFromMarkdownRequest): RichDocV2Normalized {
        return richDocV2NormalizedFromJson(invokeMap(bridge, NativeCallMap.RICH_DOC_V2_NORMALIZE_FROM_MARKDOWN, normalizeRichDocFromMarkdownRequestToMap(request)))
    }

    override suspend fun normalizeRichDocFromHtml(request: NormalizeRichDocFromHtmlRequest): RichDocV2Normalized {
        return richDocV2NormalizedFromJson(invokeMap(bridge, NativeCallMap.RICH_DOC_V2_NORMALIZE_FROM_HTML, normalizeRichDocFromHtmlRequestToMap(request)))
    }

    override suspend fun normalizeRichDocFromDocJson(request: NormalizeRichDocFromDocJsonRequest): RichDocV2Normalized {
        return richDocV2NormalizedFromJson(invokeMap(bridge, NativeCallMap.RICH_DOC_V2_NORMALIZE_FROM_DOC_JSON, normalizeRichDocFromDocJsonRequestToMap(request)))
    }

    override suspend fun buildAnnouncement(request: BuildAnnouncementMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_ANNOUNCEMENT, buildAnnouncementMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildAudio(request: BuildAudioMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_AUDIO, buildAudioMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildCard(request: BuildCardMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_CARD, buildCardMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildCustom(request: BuildCustomMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_CUSTOM, buildCustomMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildEmoji(request: BuildEmojiMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_EMOJI, buildEmojiMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildFile(request: BuildFileMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_FILE, buildFileMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildForward(request: BuildForwardMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_FORWARD, buildForwardMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildImage(request: BuildImageMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_IMAGE, buildImageMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildImageGroup(request: BuildImageGroupMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_IMAGE_GROUP, buildImageGroupMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildLinkCard(request: BuildLinkCardMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_LINK_CARD, buildLinkCardMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildLocation(request: BuildLocationMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_LOCATION, buildLocationMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildMiniProgram(request: BuildMiniProgramMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_MINI_PROGRAM, buildMiniProgramMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildNotification(request: BuildNotificationMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_NOTIFICATION, buildNotificationMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildPlaceholder(request: BuildPlaceholderMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_PLACEHOLDER, buildPlaceholderMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildQuote(request: BuildQuoteMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_QUOTE, buildQuoteMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildRichDoc(request: BuildRichDocMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_RICH_DOC, buildRichDocMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildSchedule(request: BuildScheduleMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_SCHEDULE, buildScheduleMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildSticker(request: BuildStickerMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_STICKER, buildStickerMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildSystem(request: BuildSystemMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_SYSTEM, buildSystemMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildTask(request: BuildTaskMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_TASK, buildTaskMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildText(request: BuildTextMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_TEXT, buildTextMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildThreadReply(request: BuildThreadReplyMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_THREAD_REPLY, buildThreadReplyMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildVideo(request: BuildVideoMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_VIDEO, buildVideoMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildVote(request: BuildVoteMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_VOTE, buildVoteMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }

    override suspend fun buildWithContent(request: BuildWithContentMessageRequest): Message {
        val raw = invokeMap(bridge, NativeCallMap.MESSAGE_BUILDER_CREATE_WITH_CONTENT, buildWithContentMessageRequestToMap(request))
        return messageFromJson(raw["message"] ?: raw)
    }
}
