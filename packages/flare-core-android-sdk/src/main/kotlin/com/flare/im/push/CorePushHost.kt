package com.flare.im.push

import com.flare.im.api.FlareImClient
import com.flare.im.model.command.ClearPushTokenRequest
import com.flare.im.model.command.HandleRemoteMessageRequest
import com.flare.im.model.command.ResolveNotificationTapRequest
import com.flare.im.model.command.SetBackgroundPresenterRequest
import com.flare.im.model.command.SetPushPermissionRequest
import com.flare.im.model.entity.NotificationPresentation
import com.flare.im.model.entity.PushTokenInput
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.buffer
import kotlinx.coroutines.flow.callbackFlow

/**
 * 核心客户端上的推送宿主：平台推送模块经它调 `session` 模块的推送接口与未读总数，客户端的 `notification.clear`
 * 与 `notification.badge` 事件转成更正交给模块（[notificationCorrections]），通知由模块照办。后台展示器经它报
 * `notification.set_background_presenter`，并收客户端的 `notification.present`（[notificationPresentations]）；
 * 常驻连接模式经它撤推送绑定（`sdk.clear_push_token`）。
 *
 * 事件经客户端本地的监听者转来：应用照常打开的那一路原生事件订阅（`client.events.subscribeEvents`）要开着。
 *
 * ```
 * // signedInClient()：应用自己的「已登录或已恢复会话的 FlareImClient，否则 null」，可以挂起等初始化
 * FlarePush.install(application, hostProvider = { signedInClient()?.let(::CorePushHost) })
 * ```
 *
 * 生成的模型里，取值固定的几个字段可能是字符串，也可能是枚举；数值可能是 Int 也可能是 Long。
 * 这里一律按线上的写法转换（[wireName]、[wireLong]），两种生成形态都能对上。
 */
class CorePushHost(private val client: FlareImClient) : FlarePushHost {
    override suspend fun updatePushToken(token: PlatformPushToken) {
        client.updatePushToken(
            PushTokenInput(
                platform = token.platform,
                provider = token.provider,
                token = token.token,
                appBundle = token.appBundle,
                environment = token.environment,
                locale = token.locale,
                timeZone = token.timeZone,
                appVersion = token.appVersion,
                capabilities = token.capabilities,
            ),
        )
    }

    override suspend fun setPushPermission(allowed: Boolean) {
        client.setPushPermission(SetPushPermissionRequest(allowed = allowed))
    }

    override suspend fun reconcilePush() {
        client.reconcilePush()
    }

    override suspend fun handleRemoteMessage(
        provider: String,
        payload: Map<String, String>,
        budgetMs: Int,
    ): PlatformPushOutcome {
        val outcome = client.handleRemoteMessage(
            HandleRemoteMessageRequest(provider = provider, payload = payload, budgetMs = budgetMs),
        )
        return PlatformPushOutcome(
            action = PlatformPushAction.fromWire(wireName(outcome.action)),
            presentation = outcome.presentation?.let(::platformPresentation),
            clearCollapseIds = outcome.clearCollapseIds.orEmpty().filter { it.isNotBlank() },
            badge = wireLong(outcome.badge)?.toInt(),
            reason = wireName(outcome.reason),
        )
    }

    override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? {
        val result = client.resolveNotificationTap(ResolveNotificationTapRequest(payload = payload))
        val conversationId = result.conversationId?.takeIf { it.isNotBlank() } ?: return null
        return PlatformTapRoute(
            conversationId = conversationId,
            messageId = result.messageId?.takeIf { it.isNotBlank() },
            seq = wireLong(result.seq),
        )
    }

    override suspend fun totalUnread(): Int =
        client.conversations.getTotalUnread().totalUnread.coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()

    /** 模块收集期间监听客户端的清除与角标事件，收集结束时退掉监听。事件不丢：缓冲不设上限。 */
    override fun notificationCorrections(): Flow<PlatformNotificationCorrection> = callbackFlow {
        val cleared = client.events.onNotificationClear { event ->
            trySend(
                if (event.all == true) {
                    PlatformNotificationCorrection.ClearAll
                } else {
                    PlatformNotificationCorrection.Clear(event.collapseIds.orEmpty().filter { it.isNotBlank() })
                },
            )
        }
        val badges = client.events.onNotificationBadge { event ->
            trySend(PlatformNotificationCorrection.Badge((wireLong(event.count) ?: 0L).toInt().coerceAtLeast(0)))
        }
        awaitClose {
            cleared.unsubscribe()
            badges.unsubscribe()
        }
    }.buffer(Channel.UNLIMITED)

    /**
     * 模块收集期间监听客户端的 `notification.present`，收集结束时退掉监听；展示面由模块看。标题与正文是消息预览，
     * 不进日志。事件不丢：缓冲不设上限。
     */
    override fun notificationPresentations(): Flow<PlatformPushPresentation> = callbackFlow {
        val presented = client.events.onNotificationPresent { shown ->
            platformPresentation(shown)?.let { trySend(it) }
        }
        awaitClose { presented.unsubscribe() }
    }.buffer(Channel.UNLIMITED)

    override suspend fun setBackgroundPresenter(attached: Boolean) {
        client.notification.setBackgroundPresenter(SetBackgroundPresenterRequest(attached = attached))
    }

    override suspend fun clearPushToken(provider: String) {
        client.clearPushToken(ClearPushTokenRequest(provider = provider))
    }
}

/** 引擎的 `NotificationPresentation` 落成模块的值类型；没有合并键的展示意图没法落成通知，为 null。 */
private fun platformPresentation(shown: NotificationPresentation): PlatformPushPresentation? {
    val collapseId = shown.collapseId.orEmpty()
    if (collapseId.isBlank()) return null
    return PlatformPushPresentation(
        collapseId = collapseId,
        threadId = shown.threadId.orEmpty().ifEmpty { collapseId },
        conversationId = shown.conversationId.orEmpty(),
        messageId = shown.messageId.orEmpty(),
        seq = wireLong(shown.seq) ?: 0L,
        title = shown.title.orEmpty(),
        body = shown.body.orEmpty(),
        count = (wireLong(shown.count)?.toInt() ?: 1).coerceAtLeast(1),
        sound = shown.sound == true,
        channel = PlatformPushChannel.fromWire(wireName(shown.channel)),
        surface = PlatformPushSurface.fromWire(wireName(shown.surface)),
    )
}

/** 枚举按线上写法（`BADGE_ONLY` 与 `badgeOnly` 由 `fromWire` 归一），字符串原样；空为 null。 */
private fun wireName(value: Any?): String? = when (value) {
    null -> null
    is Enum<*> -> value.name
    else -> value.toString()
}?.takeIf { it.isNotBlank() }

private fun wireLong(value: Any?): Long? = when (value) {
    is Number -> value.toLong()
    is String -> value.toLongOrNull()
    else -> null
}
