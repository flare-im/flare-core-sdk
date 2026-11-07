package com.flare.im.update

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class FlareUpdateCodecTest {
    /** The full payload of the interface document. */
    @Test
    fun readsAFullStatus() {
        val json = JSONObject(
            """
            {
              "state": "downloading",
              "current": {"version": "2.3.2", "build": 20302, "channel": "stable", "distribution": "direct"},
              "release": {"releaseId": "rel_01JC8W", "version": "2.4.0", "build": 20400, "notes": ["a", "b"],
                          "sizeBytes": 52428800, "mandatory": false, "recommended": true, "kind": "package"},
              "progress": {"received": 1048576, "total": 52428800},
              "prompt": "sheet",
              "blockUi": false,
              "readOnly": true,
              "lastCheckedAt": 1793871062839,
              "error": {"code": "update.hashMismatch", "retryable": true, "fallbackUrl": "https://example.com"}
            }
            """.trimIndent(),
        )

        val status = FlareUpdateCodec.status(json.toFlareUpdateMap())

        assertEquals(FlareUpdateState.DOWNLOADING, status.state)
        assertEquals(20302L, status.current.build)
        assertEquals(listOf("a", "b"), status.release?.notes)
        assertEquals(FlareUpdateKind.PACKAGE, status.release?.kind)
        assertEquals(true, status.release?.recommended)
        assertEquals(FlareUpdateProgress(1048576, 52428800), status.progress)
        assertEquals(FlareUpdatePromptForm.SHEET, status.prompt)
        assertEquals(true, status.readOnly)
        assertEquals(1793871062839L, status.lastCheckedAt)
        assertEquals(FlareUpdateError("update.hashMismatch", true, "https://example.com"), status.error)
    }

    /** JSON null arrives as `JSONObject.NULL`; it must read as absent. */
    @Test
    fun readsNullsAsAbsent() {
        val json = JSONObject("""{"state": "idle", "release": null, "progress": null, "lastCheckedAt": null, "error": null}""")
        val status = FlareUpdateCodec.status(json.toFlareUpdateMap())
        assertNull(status.release)
        assertNull(status.progress)
        assertNull(status.lastCheckedAt)
        assertNull(status.error)
    }

    @Test
    fun refusesAnUnknownState() {
        assertThrows(IllegalArgumentException::class.java) {
            FlareUpdateCodec.status(mapOf("state" to "unheardOf"))
        }
    }

    @Test
    fun readsTheStorePlan() {
        val plan = FlareUpdateCodec.plan(
            JSONObject(
                """{"kind": "openStore", "store": "play", "url": "https://x", "packageName": "com.acme.chat", "appId": null, "immediate": true}""",
            ).toFlareUpdateMap(),
        )
        assertEquals(
            FlareUpdateInstallPlan.OpenStore("play", "https://x", "com.acme.chat", null, immediate = true),
            plan,
        )
    }

    @Test
    fun readsThePackagePlan() {
        assertEquals(
            FlareUpdateInstallPlan.InstallPackage("/data/cache/2.4.0-20400.apk", "aa", "bb", 20400, 52428800),
            FlareUpdateCodec.plan(PACKAGE_PLAN),
        )
    }

    /** Another platform's plan is a value, not a crash: the installer fails it and reports. */
    @Test
    fun keepsAPlanForAnotherPlatform() {
        assertEquals(
            FlareUpdateInstallPlan.Unsupported("activateWebBundle"),
            FlareUpdateCodec.plan(mapOf("kind" to "activateWebBundle", "buildId" to "20261105-abc")),
        )
    }

    @Test
    fun refusesAPackagePlanWithoutACertificate() {
        assertThrows(IllegalArgumentException::class.java) {
            FlareUpdateCodec.plan(PACKAGE_PLAN - "signingCertSha256")
        }
    }

    @Test
    fun theReportCarriesTheCodeOnlyWhenThereIsOne() {
        assertEquals(
            mapOf("outcome" to "failed", "code" to "update.signatureMismatch"),
            FlareUpdateCodec.reportParams(FlareUpdateInstallResult.failed("update.signatureMismatch")),
        )
        assertEquals(
            mapOf("outcome" to "started"),
            FlareUpdateCodec.reportParams(FlareUpdateInstallResult(FlareUpdateOutcome.STARTED)),
        )
    }
}
