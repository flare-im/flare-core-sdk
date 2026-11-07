package com.flare.im.lifecycle

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * The installed package's version facts for `sdkConfig.app`: `versionName`, `versionCode` and
 * the distribution read from the install source. Keys it cannot read are left out.
 */
internal object AppInfoReader {
    fun read(context: Context): Map<String, Any?> {
        val manager = context.packageManager
        val name = context.packageName
        val info = try {
            packageInfo(manager, name)
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        return buildMap {
            info?.versionName?.trim()?.takeIf { it.isNotEmpty() }?.let { put("version", it) }
            info?.let { put("build", versionCode(it)) }
            distributionOf(installer(manager, name))?.let { put("distribution", it) }
        }
    }

    /**
     * The distribution for an installing package: `play` and `appgallery` for their stores,
     * `direct` for side loads (package installer, adb, or none recorded). Other stores give none
     * rather than a guess; hosts that ship there set `app.distribution` themselves.
     */
    fun distributionOf(installer: String?): String? = when (installer) {
        null,
        "",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.shell",
        -> "direct"
        "com.android.vending" -> "play"
        "com.huawei.appmarket" -> "appgallery"
        else -> null
    }

    private fun packageInfo(manager: PackageManager, name: String): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.getPackageInfo(name, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            manager.getPackageInfo(name, 0)
        }

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }

    private fun installer(manager: PackageManager, name: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.getInstallSourceInfo(name).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            manager.getInstallerPackageName(name)
        }
    } catch (_: PackageManager.NameNotFoundException) {
        null
    } catch (_: IllegalArgumentException) {
        null
    }
}
