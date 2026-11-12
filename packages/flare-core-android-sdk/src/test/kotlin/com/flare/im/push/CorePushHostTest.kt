package com.flare.im.push

import com.flare.im.adapter.DefaultFlareImClient
import com.flare.im.adapter.module.DefaultEventsApi
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallDescriptor
import com.flare.im.model.entity.NotificationBadgeEvent
import com.flare.im.model.entity.NotificationClearEvent
import com.flare.im.model.entity.NotificationPresentation
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 推送宿主接到核心客户端的契约操作上；平台模块自己的行为在 flare-core-android-push 里测。 */
class CorePushHostTest {
    /** 按操作给出固定答复，记下每次调用的请求。 */
    private class CannedBridge(private val answers: Map<String, Map<String, Any?>>) : NativeBridge {
        val calls = mutableListOf<Pair<String, Map<String, Any?>>>()

        override suspend fun <T> invoke(descriptor: NativeCallDescriptor, request: Any?): T {
            @Suppress("UNCHECKED_CAST")
            calls += descriptor.operation to (request as? Map<String, Any?>).orEmpty()
            @Suppress("UNCHECKED_CAST")
            return (answers[descriptor.operation] ?: emptyMap<String, Any?>()) as T
        }

        fun request(operation: String): Map<String, Any?> = calls.last { it.first == operation }.second
    }

    private val status = mapOf<String, Any?>(
        "state" to "registered",
        "configuredProviders" to 1L,
        "registeredProviders" to 1L,
        "pendingRevocations" to 0L,
    )

    private val payload = mapOf("conversation_id" to "conv-1", "collapse_id" to "c:1", "seq" to "5")

    @Test
    fun aRemoteMessageGoesThroughTheEngineAndComesBackAsAnOutcome() = runBlocking {
        val bridge = CannedBridge(
            mapOf(
                "sdk.handle_remote_message" to mapOf(
                    "action" to "present",
                    "presentation" to mapOf(
                        "collapseId" to "c:1",
                        "threadId" to "c:1",
                        "conversationId" to "conv-1",
                        "messageId" to "m-1",
                        "seq" to 5L,
                        "title" to "Alice",
                        "body" to "hi",
                        "count" to 2L,
                        "sound" to true,
                        "channel" to "mentions",
                        "surface" to "system",
                    ),
                    "clearCollapseIds" to listOf("c:old"),
                    "badge" to 3L,
                ),
            ),
        )
        val host = CorePushHost(DefaultFlareImClient(bridge))

        val outcome = host.handleRemoteMessage("fcm", payload, 8_000)

        val request = bridge.request("sdk.handle_remote_message")
        assertEquals("fcm", request["provider"])
        assertEquals(payload, request["payload"])
        assertEquals(8_000L, (request["budgetMs"] as Number).toLong())
        assertEquals(PlatformPushAction.PRESENT, outcome.action)
        assertEquals(listOf("c:old"), outcome.clearCollapseIds)
        assertEquals(3, outcome.badge)
        assertEquals(
            PlatformPushPresentation(
                collapseId = "c:1",
                threadId = "c:1",
                conversationId = "conv-1",
                messageId = "m-1",
                seq = 5L,
                title = "Alice",
                body = "hi",
                count = 2,
                sound = true,
                channel = PlatformPushChannel.MENTIONS,
                surface = PlatformPushSurface.SYSTEM,
            ),
            outcome.presentation,
        )
    }

    @Test
    fun aTapResolvesToAConversationOrNothing() = runBlocking {
        val routed = CorePushHost(
            DefaultFlareImClient(
                CannedBridge(
                    mapOf(
                        "sdk.resolve_notification_tap" to mapOf("conversationId" to "conv-1", "messageId" to "m-1", "seq" to 5L),
                    ),
                ),
            ),
        )
        assertEquals(PlatformTapRoute("conv-1", "m-1", 5L), routed.resolveNotificationTap(payload))

        val foreign = CorePushHost(DefaultFlareImClient(CannedBridge(emptyMap())))
        assertNull(foreign.resolveNotificationTap(payload))
    }

    @Test
    fun tokenPermissionAndUnreadUseTheExistingOperations() = runBlocking {
        val bridge = CannedBridge(
            mapOf(
                "sdk.update_push_token" to status,
                "sdk.set_push_permission" to status,
                "sdk.reconcile_push" to status,
                "conversation.total_unread" to mapOf("totalUnread" to 12L),
            ),
        )
        val host = CorePushHost(DefaultFlareImClient(bridge))

        host.updatePushToken(
            PlatformPushToken(
                provider = "fcm",
                token = "tok",
                appBundle = "com.acme.chat",
                locale = "zh-CN",
                timeZone = "Asia/Shanghai",
                appVersion = "2.4.0",
                capabilities = listOf("dataMessages"),
            ),
        )
        host.setPushPermission(false)
        host.reconcilePush()

        val token = bridge.request("sdk.update_push_token")
        assertEquals("fcm", token["provider"])
        assertEquals("android", token["platform"])
        assertEquals("tok", token["token"])
        assertEquals("com.acme.chat", token["appBundle"])
        assertEquals("zh-CN", token["locale"])
        assertEquals("Asia/Shanghai", token["timeZone"])
        assertEquals("2.4.0", token["appVersion"])
        assertEquals(listOf("dataMessages"), token["capabilities"])
        assertEquals(false, bridge.request("sdk.set_push_permission")["allowed"])
        assertEquals(12, host.totalUnread())
        assertEquals(
            listOf("sdk.update_push_token", "sdk.set_push_permission", "sdk.reconcile_push", "conversation.total_unread"),
            bridge.calls.map { it.first },
        )
    }

    @Test
    fun clearAndBadgeEventsBecomeCorrections() = runBlocking {
        val client = DefaultFlareImClient(CannedBridge(emptyMap()))
        val events = client.events as DefaultEventsApi
        val host = CorePushHost(client)
        val received = mutableListOf<PlatformNotificationCorrection>()
        val collecting = launch { host.notificationCorrections().take(3).toList(received) }
        // 让收集先跑起来、装上监听
        repeat(3) { yield() }

        events.emit(NotificationClearEvent(all = false, collapseIds = listOf("c:1", "c:2")))
        events.emit(NotificationBadgeEvent(count = 3))
        events.emit(NotificationClearEvent(all = true, collapseIds = emptyList()))
        collecting.join()

        assertEquals(
            listOf(
                PlatformNotificationCorrection.Clear(listOf("c:1", "c:2")),
                PlatformNotificationCorrection.Badge(3),
                PlatformNotificationCorrection.ClearAll,
            ),
            received,
        )
    }

    @Test
    fun theBackgroundPresenterAndBindingRemovalUseTheirOperations() = runBlocking {
        val bridge = CannedBridge(mapOf("sdk.clear_push_token" to status))
        val host = CorePushHost(DefaultFlareImClient(bridge))

        host.setBackgroundPresenter(true)
        host.clearPushToken("getui")

        assertEquals(true, bridge.request("notification.set_background_presenter")["attached"])
        assertEquals("getui", bridge.request("sdk.clear_push_token")["provider"])
    }

    @Test
    fun presentEventsBecomePresentations() = runBlocking {
        val client = DefaultFlareImClient(CannedBridge(emptyMap()))
        val events = client.events as DefaultEventsApi
        val host = CorePushHost(client)
        val received = mutableListOf<PlatformPushPresentation>()
        val collecting = launch { host.notificationPresentations().take(1).toList(received) }
        repeat(3) { yield() }

        events.emit(
            NotificationPresentation(
                collapseId = "c:1",
                threadId = "c:1",
                conversationId = "conv-1",
                messageId = "m-1",
                seq = 5,
                title = "Alice",
                body = "hi",
                count = 1,
                sound = false,
                channel = "quiet",
                surface = "system",
            ),
        )
        collecting.join()

        assertEquals(1, received.size)
        assertEquals("conv-1", received[0].conversationId)
        assertEquals(PlatformPushChannel.QUIET, received[0].channel)
        assertEquals(PlatformPushSurface.SYSTEM, received[0].surface)
        assertEquals(false, received[0].sound)
    }
}
