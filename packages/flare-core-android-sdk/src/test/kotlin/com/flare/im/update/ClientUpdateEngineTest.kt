package com.flare.im.update

import com.flare.im.model.entity.UpdateCurrentApp
import com.flare.im.model.entity.UpdateErrorInfo
import com.flare.im.model.entity.UpdateInstallPlan
import com.flare.im.model.entity.UpdateProgress
import com.flare.im.model.entity.UpdateReleaseSummary
import com.flare.im.model.entity.UpdateResourcePack
import com.flare.im.model.entity.UpdateResources
import com.flare.im.model.entity.UpdateStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ClientUpdateEngineTest {
    private val status = UpdateStatus(
        state = "downloading",
        current = UpdateCurrentApp(version = "2.3.2", build = 20302, channel = "stable", distribution = "direct"),
        release = UpdateReleaseSummary(
            releaseId = "rel_01JC8W",
            version = "2.4.0",
            build = 20400,
            notes = listOf("Scheduled messages"),
            sizeBytes = 52428800,
            mandatory = true,
            kind = "package",
        ),
        progress = UpdateProgress(received = 1048576, total = 52428800),
        prompt = "modal",
        blockUi = true,
        readOnly = true,
        blockReason = "No longer supported",
        lastCheckedAt = 1793871062839,
        error = UpdateErrorInfo(code = "update.hashMismatch", retryable = true, fallbackUrl = "https://example.com"),
    )

    /** What the controller reads is what the client said: the field names are the wire's. */
    @Test
    fun aStatusSurvivesTheWayToTheController() {
        val read = FlareUpdateCodec.status(status.toWire())

        assertEquals(FlareUpdateState.DOWNLOADING, read.state)
        assertEquals(FlareUpdateCurrent("2.3.2", 20302, "stable", "direct"), read.current)
        assertEquals("2.4.0", read.release?.version)
        assertEquals(20400L, read.release?.build)
        assertEquals(listOf("Scheduled messages"), read.release?.notes)
        assertEquals(52428800L, read.release?.sizeBytes)
        assertEquals(true, read.release?.mandatory)
        assertEquals(FlareUpdateKind.PACKAGE, read.release?.kind)
        assertEquals(FlareUpdateProgress(1048576, 52428800), read.progress)
        assertEquals(FlareUpdatePromptForm.MODAL, read.prompt)
        assertEquals(true, read.blockUi)
        assertEquals(true, read.readOnly)
        assertEquals("No longer supported", read.blockReason)
        assertEquals(1793871062839L, read.lastCheckedAt)
        assertEquals(FlareUpdateError("update.hashMismatch", true, "https://example.com"), read.error)
    }

    @Test
    fun aQuietStatusHasNoReleaseProgressOrError() {
        val read = FlareUpdateCodec.status(status.copy(release = null, progress = null, error = null).toWire())
        assertNull(read.release)
        assertNull(read.progress)
        assertNull(read.error)
    }

    @Test
    fun resourcePacksSurviveTheWayToTheController() {
        val resources = UpdateResources(
            packs = listOf(UpdateResourcePack(id = "strings", kind = "strings", packVersion = 3, contentJson = "{}")),
        )
        assertEquals(
            listOf(FlareUpdateResourcePack("strings", "strings", 3, "{}")),
            FlareUpdateCodec.resourcePacks(resources.toWire()),
        )
    }

    @Test
    fun aStorePlanSurvivesTheWayToTheInstaller() {
        val plan = UpdateInstallPlan(kind = "openStore", store = "play", packageName = "com.acme.chat", immediate = true)
        assertEquals(
            FlareUpdateInstallPlan.OpenStore(store = "play", packageName = "com.acme.chat", immediate = true),
            FlareUpdateCodec.plan(plan.toWire()),
        )
    }

    @Test
    fun aPackagePlanSurvivesTheWayToTheInstaller() {
        val plan = UpdateInstallPlan(
            kind = "installPackage",
            path = "/data/2.4.0-20400.apk",
            sha256 = "aa",
            signingCertSha256 = "bb",
            build = 20400,
            sizeBytes = 52428800,
        )
        assertEquals(
            FlareUpdateInstallPlan.InstallPackage("/data/2.4.0-20400.apk", "aa", "bb", 20400, 52428800),
            FlareUpdateCodec.plan(plan.toWire()),
        )
    }
}
