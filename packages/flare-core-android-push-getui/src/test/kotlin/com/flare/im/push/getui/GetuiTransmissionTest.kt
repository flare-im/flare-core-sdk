package com.flare.im.push.getui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GetuiTransmissionTest {
    /** 透传是载荷 JSON 的 UTF-8 字节；数字也读成字符串，与 FCM 数据消息同形。 */
    @Test
    fun aTransmissionReadsAsThePayloadMap() {
        val bytes = """{"conversation_id":"conv-1","collapse_id":"c:1","seq":42,"title":"张三","body":"在吗"}"""
            .toByteArray(Charsets.UTF_8)
        assertEquals(
            mapOf("conversation_id" to "conv-1", "collapse_id" to "c:1", "seq" to "42", "title" to "张三", "body" to "在吗"),
            GetuiTransmission.payload(bytes),
        )
    }

    @Test
    fun anythingElseIsNoPayload() {
        assertNull(GetuiTransmission.payload(null))
        assertNull(GetuiTransmission.payload(ByteArray(0)))
        assertNull(GetuiTransmission.payload("hello".toByteArray()))
        assertNull(GetuiTransmission.payload("{}".toByteArray()))
    }
}
