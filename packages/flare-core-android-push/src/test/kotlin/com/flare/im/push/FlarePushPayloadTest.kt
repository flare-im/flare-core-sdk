package com.flare.im.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FlarePushPayloadTest {
    private val loud = mapOf(
        "uid" to "u1",
        "tenant_id" to "t1",
        "conversation_id" to "conv-1",
        "message_id" to "m-9",
        "seq" to "42",
        "collapse_id" to "c:0123456789abcdef0123456789abcdef",
        "thread_id" to "c:0123456789abcdef0123456789abcdef",
        "disposition" to "loud",
        "alert_class" to "normal",
        "count" to "3",
        "badge" to "12",
        "title" to "[3条] Alice",
        "body" to "see you",
        "sound" to "1",
    )

    /** 没有宿主时按载荷原样展示：处置决定动作，提示等级决定渠道，字段原样搬过去。 */
    @Test
    fun aLoudPayloadPresentsAsIs() {
        val outcome = FlarePushPayload.fallbackOutcome(loud)
        assertEquals(PlatformPushAction.PRESENT, outcome.action)
        assertEquals(12, outcome.badge)
        val presentation = outcome.presentation!!
        assertEquals("c:0123456789abcdef0123456789abcdef", presentation.collapseId)
        assertEquals("conv-1", presentation.conversationId)
        assertEquals("m-9", presentation.messageId)
        assertEquals(42L, presentation.seq)
        assertEquals(3, presentation.count)
        assertEquals("[3条] Alice", presentation.title)
        assertTrue(presentation.sound)
        assertEquals(PlatformPushChannel.MESSAGES, presentation.channel)
        assertEquals(PlatformPushSurface.SYSTEM, presentation.surface)
    }

    @Test
    fun alertClassPicksTheChannel() {
        assertEquals(
            PlatformPushChannel.MENTIONS,
            FlarePushPayload.fallbackOutcome(loud + ("alert_class" to "mention")).presentation?.channel,
        )
        assertEquals(
            PlatformPushChannel.URGENT,
            FlarePushPayload.fallbackOutcome(loud + ("alert_class" to "urgent")).presentation?.channel,
        )
    }

    /** 静默更新与撤回替换都是不响铃的替换；只有 quiet 处置走静默渠道。 */
    @Test
    fun quietAndRecallReplaceUpdateWithoutSound() {
        val quiet = FlarePushPayload.fallbackOutcome(loud + ("disposition" to "quiet"))
        assertEquals(PlatformPushAction.UPDATE, quiet.action)
        assertEquals(PlatformPushChannel.QUIET, quiet.presentation?.channel)
        assertFalse(quiet.presentation!!.sound)

        val recall = FlarePushPayload.fallbackOutcome(loud + ("disposition" to "recall_replace"))
        assertEquals(PlatformPushAction.UPDATE, recall.action)
        assertEquals(PlatformPushChannel.MESSAGES, recall.presentation?.channel)
        assertFalse(recall.presentation!!.sound)
    }

    @Test
    fun clearAndBadgeOnlyShowNothing() {
        val clear = FlarePushPayload.fallbackOutcome(loud + ("disposition" to "clear"))
        assertEquals(PlatformPushAction.CLEAR, clear.action)
        assertEquals(listOf("c:0123456789abcdef0123456789abcdef"), clear.clearCollapseIds)
        assertNull(clear.presentation)

        val badge = FlarePushPayload.fallbackOutcome(loud + ("disposition" to "badge_only"))
        assertEquals(PlatformPushAction.BADGE_ONLY, badge.action)
        assertEquals(12, badge.badge)
        assertNull(badge.presentation)
    }

    @Test
    fun soundFollowsTheSoundKey() {
        assertFalse(FlarePushPayload.fallbackOutcome(loud + ("sound" to "0")).presentation!!.sound)
        assertFalse(FlarePushPayload.fallbackOutcome(loud - "sound" + ("alert_class" to "silent")).presentation!!.sound)
        assertTrue(FlarePushPayload.fallbackOutcome(loud - "sound").presentation!!.sound)
    }

    /** 缺处置时按响铃，宁可多提示；没有标题也没有正文就没东西可展示。 */
    @Test
    fun aMissingDispositionPresentsAndAnEmptyAlertIsIgnored() {
        assertEquals(PlatformPushAction.PRESENT, FlarePushPayload.fallbackOutcome(loud - "disposition").action)
        val empty = FlarePushPayload.fallbackOutcome(loud - "title" - "body")
        assertEquals(PlatformPushAction.IGNORE, empty.action)
        assertEquals("malformed", empty.reason)
    }

    @Test
    fun aMissingCollapseIdFallsBackToTheConversation() {
        val outcome = FlarePushPayload.fallbackOutcome(loud - "collapse_id" - "thread_id")
        assertEquals("conv-1", outcome.presentation?.collapseId)
        assertEquals("conv-1", outcome.presentation?.threadId)
    }

    /** 个推透传与意图附加数据里的 JSON：数字转成字符串，null 丢掉，不是对象就不认。 */
    @Test
    fun decodeReadsStringsAndNumbers() {
        val decoded = FlarePushPayload.decode("""{"seq":42,"count":"2","title":"hi","badge":null}""")
        assertEquals(mapOf("seq" to "42", "count" to "2", "title" to "hi"), decoded)
        assertNull(FlarePushPayload.decode("not json"))
        assertNull(FlarePushPayload.decode(""))
        assertEquals(loud, FlarePushPayload.decode(FlarePushPayload.encode(loud)))
    }

    @Test
    fun theWireOutcomeAcceptsEitherSpelling() {
        val outcome = PlatformPushWire.outcome(
            mapOf(
                "action" to "BADGE_ONLY",
                "clearCollapseIds" to listOf("c:a", "", null),
                "badge" to 4L,
                "presentation" to mapOf(
                    "collapseId" to "c:a",
                    "threadId" to "c:a",
                    "conversationId" to "conv",
                    "messageId" to "m",
                    "seq" to "18446744073709551",
                    "title" to "t",
                    "body" to "b",
                    "count" to 2,
                    "sound" to true,
                    "channel" to "mentions",
                    "surface" to "IN_APP",
                ),
            ),
        )
        assertEquals(PlatformPushAction.BADGE_ONLY, outcome.action)
        assertEquals(listOf("c:a"), outcome.clearCollapseIds)
        assertEquals(4, outcome.badge)
        assertEquals(18446744073709551L, outcome.presentation?.seq)
        assertEquals(PlatformPushChannel.MENTIONS, outcome.presentation?.channel)
        assertEquals(PlatformPushSurface.IN_APP, outcome.presentation?.surface)
        assertEquals(PlatformPushAction.BADGE_ONLY, PlatformPushWire.outcome(mapOf("action" to "badgeOnly")).action)
        assertEquals(PlatformPushAction.IGNORE, PlatformPushWire.outcome(mapOf("action" to "dance")).action)
    }

    @Test
    fun aTapForAnotherAccountHasNoRoute() {
        assertNull(PlatformPushWire.tapRoute(emptyMap()))
        assertEquals(
            PlatformTapRoute("conv", "m", 7L),
            PlatformPushWire.tapRoute(mapOf("conversationId" to "conv", "messageId" to "m", "seq" to 7)),
        )
    }

    @Test
    fun aTapRouteRoundTrips() {
        val route = PlatformTapRoute("conv", "m", 7L)
        assertEquals(mapOf("conversationId" to "conv", "messageId" to "m", "seq" to 7L), PlatformPushWire.tapResult(route))
        assertEquals(route, PlatformPushWire.tapRoute(PlatformPushWire.tapResult(route)))
        assertEquals(mapOf("conversationId" to "conv"), PlatformPushWire.tapResult(PlatformTapRoute("conv")))
    }

    @Test
    fun theTokenRequestOmitsAbsentFields() {
        val request = PlatformPushWire.tokenRequest(
            PlatformPushToken(
                provider = "fcm",
                token = "tok",
                appBundle = "com.acme.chat",
                locale = "zh-CN",
                capabilities = listOf("dataMessages"),
            ),
        )
        assertEquals(
            mapOf(
                "provider" to "fcm",
                "platform" to "android",
                "token" to "tok",
                "appBundle" to "com.acme.chat",
                "locale" to "zh-CN",
                "capabilities" to listOf("dataMessages"),
            ),
            request,
        )
        assertFalse(PlatformPushToken("fcm", "secret-token").toString().contains("secret-token"))
    }

    @Test
    fun subBrandsMapToTheirSystemVendor() {
        assertEquals(FlarePushVendor.XIAOMI, FlarePushVendor.from("Xiaomi", "Redmi"))
        assertEquals(FlarePushVendor.HONOR, FlarePushVendor.from("HUAWEI", "HONOR"))
        assertEquals(FlarePushVendor.HONOR, FlarePushVendor.from("HONOR", "HONOR"))
        assertEquals(FlarePushVendor.HUAWEI, FlarePushVendor.from("HUAWEI", "HUAWEI"))
        assertEquals(FlarePushVendor.OPPO, FlarePushVendor.from("OnePlus", "OnePlus"))
        assertEquals(FlarePushVendor.VIVO, FlarePushVendor.from("vivo", "iQOO"))
        assertEquals(FlarePushVendor.OTHER, FlarePushVendor.from("Google", "google"))
        for (vendor in FlarePushVendor.values()) {
            assertEquals(vendor == FlarePushVendor.OTHER, FlarePushVendor.autoStartComponents(vendor).isEmpty())
        }
    }

    @Test
    fun clearAndBadgeEventsReadAsCorrections() {
        assertEquals(
            PlatformNotificationCorrection.Clear(listOf("c:1", "c:2")),
            PlatformPushWire.clearCorrection(mapOf("collapseIds" to listOf("c:1", " ", "c:2"), "all" to false)),
        )
        assertEquals(
            PlatformNotificationCorrection.ClearAll,
            PlatformPushWire.clearCorrection(mapOf("collapseIds" to emptyList<String>(), "all" to true)),
        )
        assertNull(PlatformPushWire.clearCorrection(mapOf("collapseIds" to emptyList<String>(), "all" to false)))
        assertEquals(PlatformNotificationCorrection.Badge(12), PlatformPushWire.badgeCorrection(mapOf("count" to 12L)))
        assertNull(PlatformPushWire.badgeCorrection(mapOf("count" to -1)))
        assertNull(PlatformPushWire.badgeCorrection(emptyMap()))
    }
}
