package com.flare.im.update

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/** What a package says about itself. [signingCerts] are lowercase SHA-256 hex of the current signers. */
internal data class FlareApkFacts(
    val packageName: String,
    val versionCode: Long,
    val signingCerts: Set<String>,
)

/** Reads a package file and the installed app; a test double replaces the system's. */
internal interface FlareApkInspector {
    /** The file's SHA-256 as lowercase hex, or null when it cannot be read. */
    fun sha256(path: String): String?

    /** The file's facts, or null when it is not a package the system can parse. */
    fun archive(path: String): FlareApkFacts?

    /** The running app's facts, or null when they cannot be read. */
    fun installed(): FlareApkFacts?
}

/**
 * The last checks before a package reaches the system. The download already verified the hash;
 * the file has sat in a cache since, so it is checked again here, along with what only the
 * platform can read: the package's signer and version.
 */
internal class FlareApkVerifier(private val inspector: FlareApkInspector) {
    /** The error code that refuses [plan], or null when the package may be installed. */
    fun verify(plan: FlareUpdateInstallPlan.InstallPackage): String? {
        val hash = inspector.sha256(plan.path) ?: return FlareUpdateErrorCodes.HASH_MISMATCH
        if (!hash.equals(plan.sha256, ignoreCase = true)) return FlareUpdateErrorCodes.HASH_MISMATCH

        val archive = inspector.archive(plan.path) ?: return FlareUpdateErrorCodes.INSTALL_FAILED
        // Unreadable facts refuse the package: nothing can then be said for its origin.
        val installed = inspector.installed() ?: return FlareUpdateErrorCodes.SIGNATURE_MISMATCH
        // A package signed by the same key but with another name would install a different app.
        if (archive.packageName != installed.packageName) return FlareUpdateErrorCodes.SIGNATURE_MISMATCH
        if (archive.signingCerts.isEmpty()) return FlareUpdateErrorCodes.SIGNATURE_MISMATCH
        if (plan.signingCertSha256.lowercase() !in archive.signingCerts) return FlareUpdateErrorCodes.SIGNATURE_MISMATCH
        if (archive.signingCerts != installed.signingCerts) return FlareUpdateErrorCodes.SIGNATURE_MISMATCH

        if (archive.versionCode <= installed.versionCode) return FlareUpdateErrorCodes.DOWNGRADE_REJECTED
        return null
    }
}

/** Reads packages with [PackageManager]. */
internal class PackageManagerApkInspector(private val context: Context) : FlareApkInspector {
    private val manager: PackageManager = context.packageManager

    override fun sha256(path: String): String? {
        val file = File(path)
        if (!file.isFile) return null
        return runCatching {
            val digest = MessageDigest.getInstance("SHA-256")
            FileInputStream(file).use { input ->
                val buffer = ByteArray(BUFFER_BYTES)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    digest.update(buffer, 0, read)
                }
            }
            hex(digest.digest())
        }.getOrNull()
    }

    override fun archive(path: String): FlareApkFacts? {
        @Suppress("DEPRECATION")
        val info = manager.getPackageArchiveInfo(path, signingFlag()) ?: return null
        return facts(info)
    }

    override fun installed(): FlareApkFacts? = runCatching {
        @Suppress("DEPRECATION")
        facts(manager.getPackageInfo(context.packageName, signingFlag()))
    }.getOrNull()

    private fun facts(info: PackageInfo): FlareApkFacts = FlareApkFacts(
        packageName = info.packageName,
        versionCode = versionCode(info),
        signingCerts = signers(info).mapTo(linkedSetOf()) { signer ->
            hex(MessageDigest.getInstance("SHA-256").digest(signer.toByteArray()))
        },
    )

    private fun signingFlag(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        PackageManager.GET_SIGNING_CERTIFICATES
    } else {
        @Suppress("DEPRECATION")
        PackageManager.GET_SIGNATURES
    }

    /** The signers of the package as it stands; rotated-out certificates of its history do not count. */
    private fun signers(info: PackageInfo): List<Signature> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.toList().orEmpty()
        } else {
            @Suppress("DEPRECATION")
            info.signatures?.toList().orEmpty()
        }

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }

    private fun hex(bytes: ByteArray): String =
        bytes.joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }

    private companion object {
        const val BUFFER_BYTES = 64 * 1024
    }
}
