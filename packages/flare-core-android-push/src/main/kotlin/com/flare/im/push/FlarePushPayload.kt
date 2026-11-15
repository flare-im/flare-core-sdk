package com.flare.im.push

import org.json.JSONObject

/**
 * 服务端下发到设备的推送载荷。各厂商用同一组蛇形键；FCM 数据消息与个推透传里的值都是字符串。
 */
object FlarePushPayload {
    const val UID = "uid"
    const val TENANT_ID = "tenant_id"
    const val CONVERSATION_ID = "conversation_id"
    const val MESSAGE_ID = "message_id"
    const val SEQ = "seq"
    const val COLLAPSE_ID = "collapse_id"
    const val THREAD_ID = "thread_id"
    const val DISPOSITION = "disposition"
    const val ALERT_CLASS = "alert_class"
    const val COUNT = "count"
    const val BADGE = "badge"
    const val TITLE = "title"
    const val BODY = "body"
    const val SOUND = "sound"

    /** 全部已知键；厂商意图把载荷逐键铺在附加数据里时按这张表收回来。 */
    val KEYS: List<String> = listOf(
        UID, TENANT_ID, CONVERSATION_ID, MESSAGE_ID, SEQ, COLLAPSE_ID, THREAD_ID,
        DISPOSITION, ALERT_CLASS, COUNT, BADGE, TITLE, BODY, SOUND,
    )

    /**
     * 载荷 JSON 读成字符串映射：个推透传、启动意图里的 [FlarePush.EXTRA_PAYLOAD] 都是这个形状。
     * 数字与布尔转成字符串，null 丢掉；不是 JSON 对象时返回 null。
     */
    fun decode(json: String?): Map<String, String>? {
        if (json.isNullOrBlank()) return null
        val objectValue = try {
            JSONObject(json)
        } catch (error: Exception) {
            return null
        }
        val payload = LinkedHashMap<String, String>()
        val keys = objectValue.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = objectValue.opt(key)
            if (value == null || value == JSONObject.NULL) continue
            payload[key] = value.toString()
        }
        return payload
    }

    /** [decode] 的反向。 */
    fun encode(payload: Map<String, String>): String {
        val objectValue = JSONObject()
        for ((key, value) in payload) objectValue.put(key, value)
        return objectValue.toString()
    }

    /**
     * 没有宿主可问时（进程被推送拉起、应用还没恢复会话，或引擎超时、出错）按载荷原样展示，
     * 规则与引擎一致：处置决定动作，提示等级决定渠道。提示宁可多一条也不能丢。
     */
    fun fallbackOutcome(payload: Map<String, String>): PlatformPushOutcome {
        val conversationId = payload[CONVERSATION_ID].orEmpty().trim()
        val collapseId = payload[COLLAPSE_ID].orEmpty().trim().ifEmpty { conversationId }.ifEmpty { DEFAULT_COLLAPSE_ID }
        val badge = payload[BADGE]?.trim()?.toIntOrNull()?.takeIf { it >= 0 }
        val action = when (wireKey(payload[DISPOSITION]?.trim())) {
            "quiet", "recallreplace" -> PlatformPushAction.UPDATE
            "clear" -> PlatformPushAction.CLEAR
            "badgeonly" -> PlatformPushAction.BADGE_ONLY
            // loud、digest，以及缺省或认不出的处置：都按响铃处理，免得漏掉提示。
            else -> PlatformPushAction.PRESENT
        }
        when (action) {
            PlatformPushAction.CLEAR ->
                return PlatformPushOutcome(action, clearCollapseIds = listOf(collapseId), badge = badge)
            PlatformPushAction.BADGE_ONLY -> return PlatformPushOutcome(action, badge = badge)
            else -> Unit
        }
        val title = payload[TITLE].orEmpty()
        val body = payload[BODY].orEmpty()
        if (title.isBlank() && body.isBlank()) {
            return PlatformPushOutcome(PlatformPushAction.IGNORE, badge = badge, reason = REASON_MALFORMED)
        }
        val alertClass = wireKey(payload[ALERT_CLASS]?.trim())
        val channel = when {
            alertClass == "mention" -> PlatformPushChannel.MENTIONS
            alertClass == "urgent" -> PlatformPushChannel.URGENT
            wireKey(payload[DISPOSITION]?.trim()) == "quiet" -> PlatformPushChannel.QUIET
            else -> PlatformPushChannel.MESSAGES
        }
        val sound = action == PlatformPushAction.PRESENT && when (payload[SOUND]?.trim()?.lowercase()) {
            "1", "true" -> true
            "0", "false" -> false
            else -> alertClass != "silent" && alertClass != "none"
        }
        return PlatformPushOutcome(
            action = action,
            presentation = PlatformPushPresentation(
                collapseId = collapseId,
                threadId = payload[THREAD_ID].orEmpty().trim().ifEmpty { collapseId },
                conversationId = conversationId,
                messageId = payload[MESSAGE_ID].orEmpty().trim(),
                seq = payload[SEQ]?.trim()?.toLongOrNull() ?: 0L,
                title = title,
                body = body,
                count = payload[COUNT]?.trim()?.toIntOrNull()?.coerceAtLeast(1) ?: 1,
                sound = sound,
                channel = channel,
                surface = PlatformPushSurface.SYSTEM,
            ),
            badge = badge,
        )
    }

    /** 载荷里既没有合并键也没有会话时用的 tag，同类通知互相覆盖而不是堆积。 */
    internal const val DEFAULT_COLLAPSE_ID = "flare"
    internal const val REASON_MALFORMED = "malformed"
}

/**
 * 引擎答复（JSON 驼峰）读成本模块的值类型。经 JSON 透传的宿主（社交 SDK、Flutter 桥）用它，
 * 免得各写一份；类型化的核心客户端不经过这里。
 */
object PlatformPushWire {
    /** `RemoteMessageOutcome`。 */
    fun outcome(wire: Map<String, Any?>): PlatformPushOutcome = PlatformPushOutcome(
        action = PlatformPushAction.fromWire(wire["action"]?.toString()),
        presentation = (wire["presentation"] as? Map<*, *>)?.let { presentation(it) },
        clearCollapseIds = (wire["clearCollapseIds"] as? List<*>).orEmpty()
            .mapNotNull { it?.toString()?.takeIf(String::isNotBlank) },
        badge = int(wire["badge"])?.takeIf { it >= 0 },
        reason = wire["reason"]?.toString()?.takeIf(String::isNotBlank),
    )

    /** `NotificationPresentation`；没有合并键的展示意图没法落成通知，按缺失处理。 */
    fun presentation(wire: Map<*, *>): PlatformPushPresentation? {
        val collapseId = wire["collapseId"]?.toString()?.takeIf(String::isNotBlank) ?: return null
        return PlatformPushPresentation(
            collapseId = collapseId,
            threadId = wire["threadId"]?.toString()?.takeIf(String::isNotBlank) ?: collapseId,
            conversationId = wire["conversationId"]?.toString().orEmpty(),
            messageId = wire["messageId"]?.toString().orEmpty(),
            seq = long(wire["seq"]) ?: 0L,
            title = wire["title"]?.toString().orEmpty(),
            body = wire["body"]?.toString().orEmpty(),
            count = (int(wire["count"]) ?: 1).coerceAtLeast(1),
            sound = bool(wire["sound"]) ?: false,
            channel = PlatformPushChannel.fromWire(wire["channel"]?.toString()),
            surface = PlatformPushSurface.fromWire(wire["surface"]?.toString()),
        )
    }

    /** `notification.clear` 的载荷 `{collapseIds, all}`；既不是全部、也没有合并键时为 null。 */
    fun clearCorrection(wire: Map<String, Any?>): PlatformNotificationCorrection? {
        if (bool(wire["all"]) == true) return PlatformNotificationCorrection.ClearAll
        val collapseIds = (wire["collapseIds"] as? List<*>).orEmpty()
            .mapNotNull { it?.toString()?.takeIf(String::isNotBlank) }
        return collapseIds.takeIf { it.isNotEmpty() }?.let { PlatformNotificationCorrection.Clear(it) }
    }

    /** `notification.badge` 的载荷 `{count}`；没有可读的角标数时为 null。 */
    fun badgeCorrection(wire: Map<String, Any?>): PlatformNotificationCorrection? =
        int(wire["count"])?.takeIf { it >= 0 }?.let { PlatformNotificationCorrection.Badge(it) }

    /** `NotificationTapResult`；没有会话（载荷不属于当前账号）时为 null。 */
    fun tapRoute(wire: Map<String, Any?>): PlatformTapRoute? {
        val conversationId = wire["conversationId"]?.toString()?.takeIf(String::isNotBlank) ?: return null
        return PlatformTapRoute(
            conversationId = conversationId,
            messageId = wire["messageId"]?.toString()?.takeIf(String::isNotBlank),
            seq = long(wire["seq"]),
        )
    }

    /** [tapRoute] 的反向：`NotificationTapResult` 的形状，没有的字段不带。 */
    fun tapResult(route: PlatformTapRoute): Map<String, Any> = buildMap {
        put("conversationId", route.conversationId)
        route.messageId?.let { put("messageId", it) }
        route.seq?.let { put("seq", it) }
    }

    /** `PushTokenInput` 的请求体；为 null 的可选字段不带。 */
    fun tokenRequest(token: PlatformPushToken): Map<String, Any?> {
        val request = linkedMapOf<String, Any?>(
            "provider" to token.provider,
            "platform" to token.platform,
            "token" to token.token,
        )
        token.appBundle?.let { request["appBundle"] = it }
        token.environment?.let { request["environment"] = it }
        token.locale?.let { request["locale"] = it }
        token.timeZone?.let { request["timeZone"] = it }
        token.appVersion?.let { request["appVersion"] = it }
        if (token.capabilities.isNotEmpty()) request["capabilities"] = token.capabilities
        return request
    }

    /** u64 可能以数字或字符串到达。 */
    fun long(value: Any?): Long? = when (value) {
        is Number -> value.toLong()
        is String -> value.trim().toLongOrNull()
        else -> null
    }

    fun int(value: Any?): Int? = long(value)?.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong())?.toInt()

    fun bool(value: Any?): Boolean? = when (value) {
        is Boolean -> value
        is Number -> value.toInt() != 0
        is String -> when (value.trim().lowercase()) {
            "true", "1" -> true
            "false", "0" -> false
            else -> null
        }
        else -> null
    }
}
