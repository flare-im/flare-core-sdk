package com.flare.im.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FlarePushPermissionTest {
    /** 能展示就是允许；要运行时授权而本模块还没弹过框是没问过；其余都是拒绝。 */
    @Test
    fun theStatusIsThreeState() {
        assertEquals(
            FlarePushPermissionStatus.GRANTED,
            permissionStatus(granted = true, needsRequest = false, asked = true),
        )
        assertEquals(
            FlarePushPermissionStatus.NOT_DETERMINED,
            permissionStatus(granted = false, needsRequest = true, asked = false),
        )
        assertEquals(
            FlarePushPermissionStatus.DENIED,
            permissionStatus(granted = false, needsRequest = true, asked = true),
        )
        // Android 13 以前在设置里关掉，或授权后在设置里关掉：没有授权框可弹。
        assertEquals(
            FlarePushPermissionStatus.DENIED,
            permissionStatus(granted = false, needsRequest = false, asked = false),
        )
    }

    @Test
    fun theWireValuesMatchTheOtherPlatforms() {
        assertEquals(
            listOf("notDetermined", "denied", "granted"),
            FlarePushPermissionStatus.values().map { it.wireValue },
        )
        assertEquals(FlarePushPermissionStatus.GRANTED, FlarePushPermissionStatus.fromWire("granted"))
        assertEquals(FlarePushPermissionStatus.DENIED, FlarePushPermissionStatus.fromWire("bogus"))
    }

    /** 限制压过放开；都没有是系统默认。 */
    @Test
    fun backgroundDeliveryFollowsTheBatterySettings() {
        assertEquals(FlarePushBackgroundDelivery.RESTRICTED, FlarePushBackgroundDelivery.from(true, true))
        assertEquals(FlarePushBackgroundDelivery.UNRESTRICTED, FlarePushBackgroundDelivery.from(false, true))
        assertEquals(FlarePushBackgroundDelivery.OPTIMIZED, FlarePushBackgroundDelivery.from(false, false))
        assertEquals(
            listOf("unrestricted", "optimized", "restricted"),
            FlarePushBackgroundDelivery.values().map { it.wireValue },
        )
        assertEquals("xiaomi", FlarePushVendor.XIAOMI.wireValue)
        assertEquals(false, FlarePushVendor.OTHER.hasAutoStartSettings)
    }

    /** 装上之前不知道系统的状态：权限与后台档位都是 null，界面据此不显示。 */
    @Test
    fun theSystemStatesAreUnknownBeforeInstall() {
        assertEquals(false, FlarePush.isInstalled)
        assertNull(FlarePush.permission.value)
        assertNull(FlarePush.backgroundDelivery.value)
    }
}
