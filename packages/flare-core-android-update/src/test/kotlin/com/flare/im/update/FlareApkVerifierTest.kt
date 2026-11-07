package com.flare.im.update

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FlareApkVerifierTest {
    private val cert = "b".repeat(64)
    private val hash = "a".repeat(64)
    private val plan = FlareUpdateInstallPlan.InstallPackage(
        path = "/data/cache/2.4.0-20400.apk",
        sha256 = hash,
        signingCertSha256 = cert,
        build = 20400,
        sizeBytes = 52428800,
    )
    private val installed = FlareApkFacts("com.acme.chat", 20302, setOf(cert))
    private val archive = FlareApkFacts("com.acme.chat", 20400, setOf(cert))

    private fun verify(
        plan: FlareUpdateInstallPlan.InstallPackage = this.plan,
        fileHash: String? = hash,
        archive: FlareApkFacts? = this.archive,
        installed: FlareApkFacts? = this.installed,
    ): String? = FlareApkVerifier(
        object : FlareApkInspector {
            override fun sha256(path: String): String? = fileHash
            override fun archive(path: String): FlareApkFacts? = archive
            override fun installed(): FlareApkFacts? = installed
        },
    ).verify(plan)

    @Test
    fun acceptsTheAnnouncedPackage() {
        assertNull(verify())
    }

    @Test
    fun comparesHexWithoutRegardToCase() {
        assertNull(verify(plan = plan.copy(sha256 = hash.uppercase(), signingCertSha256 = cert.uppercase())))
    }

    /** The cached file changed after the download verified it. */
    @Test
    fun refusesAHashMismatch() {
        assertEquals(FlareUpdateErrorCodes.HASH_MISMATCH, verify(fileHash = "c".repeat(64)))
    }

    @Test
    fun refusesAFileThatCannotBeRead() {
        assertEquals(FlareUpdateErrorCodes.HASH_MISMATCH, verify(fileHash = null))
    }

    /** The package is not signed with the certificate the signed manifest names. */
    @Test
    fun refusesACertificateOtherThanThePlanned() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(plan = plan.copy(signingCertSha256 = "d".repeat(64))),
        )
    }

    /** Both the plan and the package agree, but the app on this device was signed by someone else. */
    @Test
    fun refusesACertificateOtherThanTheInstalled() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(installed = installed.copy(signingCerts = setOf("e".repeat(64)))),
        )
    }

    @Test
    fun refusesAPackageWithAnExtraSigner() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(archive = archive.copy(signingCerts = setOf(cert, "e".repeat(64)))),
        )
    }

    @Test
    fun refusesAnUnsignedPackage() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(archive = archive.copy(signingCerts = emptySet())),
        )
    }

    @Test
    fun refusesWhenTheInstalledCertificateCannotBeRead() {
        assertEquals(FlareUpdateErrorCodes.SIGNATURE_MISMATCH, verify(installed = null))
    }

    /** Same key, other app: installing it would add an app rather than update this one. */
    @Test
    fun refusesAnotherPackageName() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(archive = archive.copy(packageName = "com.acme.other")),
        )
    }

    @Test
    fun refusesADowngrade() {
        assertEquals(
            FlareUpdateErrorCodes.DOWNGRADE_REJECTED,
            verify(archive = archive.copy(versionCode = 20100)),
        )
    }

    /** Only a larger versionCode installs; the same one would reinstall. */
    @Test
    fun refusesTheInstalledVersion() {
        assertEquals(
            FlareUpdateErrorCodes.DOWNGRADE_REJECTED,
            verify(archive = archive.copy(versionCode = 20302)),
        )
    }

    /** The certificate is checked first: a foreign downgrade says signature. */
    @Test
    fun reportsTheSignatureBeforeTheVersion() {
        assertEquals(
            FlareUpdateErrorCodes.SIGNATURE_MISMATCH,
            verify(archive = FlareApkFacts("com.acme.chat", 20100, setOf("f".repeat(64)))),
        )
    }

    @Test
    fun refusesAFileThatIsNoPackage() {
        assertEquals(FlareUpdateErrorCodes.INSTALL_FAILED, verify(archive = null))
    }
}
