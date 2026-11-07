package com.flare.im.update

import com.flare.im.bridge.FlareAppInfo
import org.junit.Assert.assertEquals
import org.junit.Test

class AppDistributionTest {
    /** The release manifest picks a package by the distribution: left empty, it finds none. */
    @Test
    fun anInstallerNobodyRecognizesCountsAsDirect() {
        assertEquals("direct", FlareAppInfo.distributionOrDirect(null))
        assertEquals("direct", FlareAppInfo.distributionOrDirect("com.android.shell"))
        assertEquals("direct", FlareAppInfo.distributionOrDirect("com.example.market"))
    }

    @Test
    fun aKnownStoreKeepsItsName() {
        assertEquals("play", FlareAppInfo.distributionOrDirect("com.android.vending"))
        assertEquals("appgallery", FlareAppInfo.distributionOrDirect("com.huawei.appmarket"))
    }
}
