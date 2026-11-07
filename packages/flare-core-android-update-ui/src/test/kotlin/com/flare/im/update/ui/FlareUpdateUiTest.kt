package com.flare.im.update.ui

import com.flare.im.ui.FlareUpdateFallbackTarget as KitFallbackTarget
import com.flare.im.ui.FlareUpdateProgress as KitProgress
import com.flare.im.ui.FlareUpdatePromptForm as KitPromptForm
import com.flare.im.update.FlareUpdateCurrent
import com.flare.im.update.FlareUpdateKind
import com.flare.im.update.FlareUpdateProgress
import com.flare.im.update.FlareUpdatePromptForm
import com.flare.im.update.FlareUpdateRelease
import com.flare.im.update.FlareUpdateState
import com.flare.im.update.FlareUpdateStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FlareUpdateUiTest {
    private val release = FlareUpdateRelease(
        releaseId = "rel_01JC8W",
        version = "2.4.0",
        build = 20400,
        kind = FlareUpdateKind.PACKAGE,
    )

    private fun status(
        state: FlareUpdateState = FlareUpdateState.AVAILABLE,
        prompt: FlareUpdatePromptForm = FlareUpdatePromptForm.NONE,
        release: FlareUpdateRelease? = this.release,
        distribution: String = "direct",
    ) = FlareUpdateStatus(
        state = state,
        current = FlareUpdateCurrent(version = "2.3.2", build = 20302, distribution = distribution),
        release = release,
        prompt = prompt,
    )

    @Test
    fun theThreeFormsReachTheKit() {
        assertEquals(KitPromptForm.Sheet, status(prompt = FlareUpdatePromptForm.SHEET).kitPromptForm)
        assertEquals(KitPromptForm.Modal, status(prompt = FlareUpdatePromptForm.MODAL).kitPromptForm)
        assertEquals(KitPromptForm.Fullscreen, status(prompt = FlareUpdatePromptForm.FULLSCREEN).kitPromptForm)
    }

    @Test
    fun aBadgeAndNoneAreNoPrompt() {
        assertNull(status(prompt = FlareUpdatePromptForm.BADGE).kitPromptForm)
        assertNull(status(prompt = FlareUpdatePromptForm.NONE).kitPromptForm)
    }

    /** The server can refuse this build before the manifest arrives: forced, and no target version to name. */
    @Test
    fun aRefusalBeforeTheManifestIsForcedAndNamesTheRunningVersion() {
        val refused = status(state = FlareUpdateState.REQUIRED, release = null)
        assertTrue(refused.kitMandatory)
        assertEquals("2.3.2", refused.kitVersion)
    }

    @Test
    fun anOptionalReleaseIsNotForced() {
        assertFalse(status().kitMandatory)
        assertEquals("2.4.0", status().kitVersion)
    }

    @Test
    fun theFallbackGoesToTheWebsiteOnlyOnADirectInstall() {
        assertEquals(KitFallbackTarget.Website, status().kitFallbackTarget)
        assertEquals(KitFallbackTarget.Store, status(distribution = "play").kitFallbackTarget)
    }

    @Test
    fun progressKeepsAnUnknownTotal() {
        val downloading = status().copy(progress = FlareUpdateProgress(received = 10, total = null))
        assertEquals(KitProgress(10, null), downloading.kitProgress)
        assertNull(status().kitProgress)
    }
}
