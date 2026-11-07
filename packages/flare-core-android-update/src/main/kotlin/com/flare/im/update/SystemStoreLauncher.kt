package com.flare.im.update

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** One way to show a store page: [packageName] pins the intent to a store app, null lets the system choose. */
internal data class FlareStoreTarget(val uri: String, val packageName: String?)

/** The store apps by the `store` value of a plan. */
internal val STORE_APP_PACKAGES: Map<String, String> = mapOf(
    "play" to "com.android.vending",
    "appgallery" to "com.huawei.appmarket",
    "honor" to "com.hihonor.appmarket",
    "xiaomi" to "com.xiaomi.market",
    "oppo" to "com.heytap.market",
    "vivo" to "com.bbk.appstore",
    "tencent" to "com.tencent.android.qqdownloader",
    "samsung" to "com.sec.android.app.samsungapps",
)

/**
 * The detail page to try, best first: the plan's link, then the `market://` page of the app, each in
 * the plan's own store before any store that answers. A website plan is its link and nothing else.
 */
internal fun storeTargets(plan: FlareUpdateInstallPlan.OpenStore, hostPackage: String): List<FlareStoreTarget> {
    val link = plan.url?.takeIf { it.isNotBlank() }
    if (plan.store == FlareUpdateInstallPlan.OpenStore.WEBSITE) {
        return listOfNotNull(link).map { FlareStoreTarget(it, null) }
    }
    val uris = listOfNotNull(link, "market://details?id=${plan.packageName ?: hostPackage}")
    val storeApp = STORE_APP_PACKAGES[plan.store] ?: return uris.map { FlareStoreTarget(it, null) }
    return uris.map { FlareStoreTarget(it, storeApp) } + uris.map { FlareStoreTarget(it, null) }
}

/** Opens the store's detail page with an intent; asking the system to start it needs no `<queries>` entry. */
internal class SystemStoreLauncher(private val context: Context) : FlareStoreLauncher {
    override fun open(plan: FlareUpdateInstallPlan.OpenStore): Boolean =
        storeTargets(plan, context.packageName).any(::launch)

    private fun launch(target: FlareStoreTarget): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target.uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (target.packageName != null) intent.setPackage(target.packageName)
        return try {
            context.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
