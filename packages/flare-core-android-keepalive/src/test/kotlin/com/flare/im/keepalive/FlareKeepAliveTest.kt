package com.flare.im.keepalive

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FlareKeepAliveTest {
    @Test
    fun bootAndPackageReplacedRestartOnlyWhenEnabled() {
        assertTrue(restartsOn(Intent.ACTION_BOOT_COMPLETED, enabled = true))
        assertTrue(restartsOn(Intent.ACTION_MY_PACKAGE_REPLACED, enabled = true))
        assertFalse(restartsOn(Intent.ACTION_BOOT_COMPLETED, enabled = false))
        assertFalse(restartsOn(Intent.ACTION_MY_PACKAGE_REPLACED, enabled = false))
        assertFalse(restartsOn("android.intent.action.SCREEN_ON", enabled = true))
        assertFalse(restartsOn(null, enabled = true))
    }

    @Test
    fun theChannelAndSubtypeMatchTheContract() {
        assertEquals("flare.keepalive", FlareKeepAlive.CHANNEL_ID)
        assertEquals("im-persistent-connection", FlareKeepAlive.SPECIAL_USE_SUBTYPE)
    }
}
