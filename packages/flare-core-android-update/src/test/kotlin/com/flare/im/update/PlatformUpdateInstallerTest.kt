package com.flare.im.update

import android.content.pm.PackageInstaller
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlatformUpdateInstallerTest {
    private val cert = "b".repeat(64)
    private val hash = "a".repeat(64)
    private val plan = FlareUpdateInstallPlan.InstallPackage("/data/cache/a.apk", hash, cert, 20400, 1024)
    private val installed = FlareApkFacts("com.acme.chat", 20302, setOf(cert))
    private val goodArchive = FlareApkFacts("com.acme.chat", 20400, setOf(cert))

    private class Sessions(
        override val installAllowed: Boolean = true,
        private val result: FlareUpdateInstallResult = FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED),
    ) : FlarePackageSessions {
        var installs = 0

        override suspend fun install(plan: FlareUpdateInstallPlan.InstallPackage): FlareUpdateInstallResult {
            installs += 1
            return result
        }
    }

    private fun installer(
        sessions: FlarePackageSessions,
        archive: FlareApkFacts = goodArchive,
        fileHash: String = hash,
        store: FlareStoreLauncher = FlareStoreLauncher { true },
    ) = PlatformUpdateInstaller(
        verifier = FlareApkVerifier(
            object : FlareApkInspector {
                override fun sha256(path: String): String = fileHash
                override fun archive(path: String): FlareApkFacts = archive
                override fun installed(): FlareApkFacts = this@PlatformUpdateInstallerTest.installed
            },
        ),
        sessions = sessions,
        store = store,
        io = Dispatchers.Unconfined,
    )

    @Test
    fun installsAVerifiedPackage() = runBlocking {
        val sessions = Sessions()
        val result = installer(sessions).execute(plan)
        assertEquals(FlareUpdateOutcome.COMPLETED, result.outcome)
        assertEquals(1, sessions.installs)
    }

    /** Whatever the refusal, the package never reaches a session. */
    @Test
    fun aRefusedPackageNeverReachesASession() = runBlocking {
        val cases = listOf(
            FlareUpdateErrorCodes.HASH_MISMATCH to { sessions: Sessions ->
                installer(sessions, fileHash = "c".repeat(64))
            },
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH to { sessions: Sessions ->
                installer(sessions, archive = goodArchive.copy(signingCerts = setOf("d".repeat(64))))
            },
            FlareUpdateErrorCodes.DOWNGRADE_REJECTED to { sessions: Sessions ->
                installer(sessions, archive = goodArchive.copy(versionCode = 20100))
            },
        )
        for ((code, build) in cases) {
            val sessions = Sessions()
            val result = build(sessions).execute(plan)
            assertEquals(FlareUpdateInstallResult.failed(code), result)
            assertEquals(code, 0, sessions.installs)
        }
    }

    /** A store build does not declare the permission, so a package plan goes nowhere. */
    @Test
    fun aBuildWithoutThePermissionRefusesPackages() = runBlocking {
        val sessions = Sessions(installAllowed = false)
        val result = installer(sessions).execute(plan)
        assertEquals(FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED), result)
        assertEquals(0, sessions.installs)
    }

    /** The engine goes back to offering the update: the user may leave the store without installing. */
    @Test
    fun aStorePageThatOpensIsDone() = runBlocking {
        val opened = mutableListOf<FlareUpdateInstallPlan.OpenStore>()
        val store = FlareStoreLauncher { opened += it; true }
        val plan = FlareUpdateInstallPlan.OpenStore("appgallery", url = "https://appgallery.huawei.com/app/C1")
        val result = installer(Sessions(), store = store).execute(plan)
        assertEquals(FlareUpdateOutcome.COMPLETED, result.outcome)
        assertEquals(listOf(plan), opened)
    }

    @Test
    fun aStoreNothingCanOpenFails() = runBlocking {
        val result = installer(Sessions(), store = { false }).execute(FlareUpdateInstallPlan.OpenStore("play"))
        assertEquals(FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED), result)
    }

    @Test
    fun aPlanForAnotherPlatformFails() = runBlocking {
        val result = installer(Sessions()).execute(FlareUpdateInstallPlan.Unsupported("activateWebBundle"))
        assertEquals(FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED), result)
    }

    @Test
    fun theStoreAppIsTriedBeforeAnyOther() {
        val plan = FlareUpdateInstallPlan.OpenStore("xiaomi", url = "https://app.mi.com/details?id=com.acme.chat")
        assertEquals(
            listOf(
                FlareStoreTarget("https://app.mi.com/details?id=com.acme.chat", "com.xiaomi.market"),
                FlareStoreTarget("market://details?id=com.host.app", "com.xiaomi.market"),
                FlareStoreTarget("https://app.mi.com/details?id=com.acme.chat", null),
                FlareStoreTarget("market://details?id=com.host.app", null),
            ),
            storeTargets(plan, "com.host.app"),
        )
    }

    @Test
    fun theDetailPageComesFromThePlanPackage() {
        val targets = storeTargets(FlareUpdateInstallPlan.OpenStore("play", packageName = "com.acme.chat"), "com.host.app")
        assertEquals(
            listOf(
                FlareStoreTarget("market://details?id=com.acme.chat", "com.android.vending"),
                FlareStoreTarget("market://details?id=com.acme.chat", null),
            ),
            targets,
        )
    }

    @Test
    fun anUnknownStoreLetsTheSystemChoose() {
        val targets = storeTargets(FlareUpdateInstallPlan.OpenStore("somestore", url = "https://s.example/a"), "com.host.app")
        assertEquals(
            listOf(
                FlareStoreTarget("https://s.example/a", null),
                FlareStoreTarget("market://details?id=com.host.app", null),
            ),
            targets,
        )
    }

    /** A website fallback is that link only; it must not turn into a store page. */
    @Test
    fun aWebsiteIsItsLinkAlone() {
        val website = FlareUpdateInstallPlan.OpenStore(FlareUpdateInstallPlan.OpenStore.WEBSITE, url = "https://example.com")
        assertEquals(listOf(FlareStoreTarget("https://example.com", null)), storeTargets(website, "com.host.app"))
        assertTrue(storeTargets(FlareUpdateInstallPlan.OpenStore(FlareUpdateInstallPlan.OpenStore.WEBSITE), "com.host.app").isEmpty())
    }

    @Test
    fun readsTheSessionStatus() {
        assertEquals(FlareUpdateOutcome.COMPLETED, installResult(PackageInstaller.STATUS_SUCCESS).outcome)
        assertEquals(FlareUpdateOutcome.CANCELLED, installResult(PackageInstaller.STATUS_FAILURE_ABORTED).outcome)
        assertEquals(
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSUFFICIENT_SPACE),
            installResult(PackageInstaller.STATUS_FAILURE_STORAGE),
        )
        assertEquals(
            FlareUpdateInstallResult.failed(FlareUpdateErrorCodes.INSTALL_FAILED),
            installResult(PackageInstaller.STATUS_FAILURE_CONFLICT),
        )
    }
}
