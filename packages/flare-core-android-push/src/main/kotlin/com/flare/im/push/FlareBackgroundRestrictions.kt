package com.flare.im.push

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/** 手机厂商，按它挑自启动设置页。 */
enum class FlarePushVendor {
    HUAWEI,
    HONOR,
    XIAOMI,
    OPPO,
    VIVO,
    OTHER,
    ;

    /** 线上的写法：小写名字，例如 `xiaomi`。 */
    val wireValue: String
        get() = name.lowercase()

    /** 有自己的自启动管理页（华为、荣耀、小米、OPPO、vivo）。 */
    val hasAutoStartSettings: Boolean
        get() = this != OTHER

    companion object {
        /** 当前设备。 */
        fun current(): FlarePushVendor = from(Build.MANUFACTURER, Build.BRAND)

        /** 子品牌归到所用系统的厂商：红米、POCO 是小米，realme、一加是 OPPO，iQOO 是 vivo。 */
        fun from(manufacturer: String?, brand: String?): FlarePushVendor {
            val maker = manufacturer.orEmpty().trim().lowercase()
            val label = brand.orEmpty().trim().lowercase()
            fun named(vararg names: String) = names.any { it == maker || it == label }
            return when {
                // 早期荣耀机型的厂商仍是华为，品牌是荣耀。
                named("honor") -> HONOR
                named("huawei") -> HUAWEI
                named("xiaomi", "redmi", "poco") -> XIAOMI
                named("oppo", "realme", "oneplus") -> OPPO
                named("vivo", "iqoo") -> VIVO
                else -> OTHER
            }
        }

        /**
         * 各厂商自启动（后台启动）管理页的候选，按系统版本从新到旧。都是系统应用的内部页面，
         * 没有公开契约，会随系统更新改名，所以只当尽力而为的引导。
         */
        internal fun autoStartComponents(vendor: FlarePushVendor): List<Pair<String, String>> = when (vendor) {
            HUAWEI -> HUAWEI_COMPONENTS
            // 早期荣耀机型用的还是华为手机管家。
            HONOR -> listOf(
                "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            ) + HUAWEI_COMPONENTS
            XIAOMI -> listOf(
                "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            )
            OPPO -> listOf(
                "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
                "com.coloros.oppoguardelf" to "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity",
            )
            VIVO -> listOf(
                "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            )
            OTHER -> emptyList()
        }

        private val HUAWEI_COMPONENTS = listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        )
    }
}

/** 系统对本应用后台运行的态度，用系统电池设置里的三档说法。变化从 [FlarePush.backgroundDelivery] 读。 */
enum class FlarePushBackgroundDelivery(val wireValue: String) {
    /** 用户把本应用放出了电池优化。 */
    UNRESTRICTED("unrestricted"),

    /** 系统默认：后台运行由系统管理。 */
    OPTIMIZED("optimized"),

    /** 用户在系统设置里限制了本应用的后台活动。 */
    RESTRICTED("restricted"),
    ;

    companion object {
        /** 限制压过放开：两者同时成立时后台照样跑不了。 */
        fun from(backgroundRestricted: Boolean, ignoringBatteryOptimizations: Boolean): FlarePushBackgroundDelivery = when {
            backgroundRestricted -> RESTRICTED
            ignoringBatteryOptimizations -> UNRESTRICTED
            else -> OPTIMIZED
        }
    }
}

/**
 * 后台限制的引导：只读状态、给出设置页，不做任何自动化。是否展示引导、何时展示由应用决定
 * （Kit 的后台限制引导行），国内厂商被划掉后能否收到提示靠的是厂商通道，这里只是加分项。
 */
object FlareBackgroundRestrictions {
    fun vendor(): FlarePushVendor = FlarePushVendor.current()

    /**
     * 电池设置里的三档，由 [isBackgroundRestricted] 与 [isIgnoringBatteryOptimizations] 合成。装上模块后
     * [FlarePush.backgroundDelivery] 在回前台时自己重读，界面收集它即可。
     */
    fun delivery(context: Context): FlarePushBackgroundDelivery = FlarePushBackgroundDelivery.from(
        backgroundRestricted = isBackgroundRestricted(context),
        ignoringBatteryOptimizations = isIgnoringBatteryOptimizations(context),
    )

    /** 应用已被用户放进电池优化白名单。 */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean = runCatching {
        context.getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(context.packageName) == true
    }.getOrDefault(false)

    /** 用户在系统设置里限制了本应用的后台活动（Android 9 起）。 */
    fun isBackgroundRestricted(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && runCatching {
            context.getSystemService(ActivityManager::class.java)?.isBackgroundRestricted == true
        }.getOrDefault(false)

    /**
     * 电池优化列表页，用户自己在里面放开本应用。不用直接弹豁免框的
     * `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`：它要额外权限，商店政策也限制。
     */
    fun batteryOptimizationSettingsIntent(): Intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

    /** 本应用的系统详情页，各种设置的兜底入口。 */
    fun appDetailsSettingsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri(context))

    /** 本机上存在的自启动管理页候选，可能为空（非国内厂商，或系统改了页面）。 */
    @Suppress("DEPRECATION")
    fun autoStartSettingsIntents(context: Context): List<Intent> {
        val packageManager = context.packageManager
        return FlarePushVendor.autoStartComponents(vendor()).mapNotNull { (packageName, className) ->
            val intent = Intent().setComponent(ComponentName(packageName, className))
            val resolved = runCatching {
                packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            }.getOrNull()
            intent.takeIf { resolved != null }
        }
    }

    /** 依次尝试自启动管理页，都打不开就退到应用详情页；全都打不开返回 false。 */
    fun openAutoStartSettings(context: Context): Boolean {
        for (intent in autoStartSettingsIntents(context)) {
            if (startGuarded(context, intent)) return true
        }
        return startGuarded(context, appDetailsSettingsIntent(context))
    }

    /** 打开电池优化列表页，打不开就退到应用详情页。 */
    fun openBatteryOptimizationSettings(context: Context): Boolean =
        startGuarded(context, batteryOptimizationSettingsIntent()) ||
            startGuarded(context, appDetailsSettingsIntent(context))
}
