package com.flare.im.update

/** The wire names of the update routes. */
object FlareUpdateOperations {
    const val GET_STATE: String = "update.get_state"
    const val CHECK: String = "update.check"
    const val DOWNLOAD: String = "update.download"
    const val INSTALL: String = "update.install"
    const val REPORT_INSTALL: String = "update.report_install"
    const val DEFER: String = "update.defer"
    const val SKIP: String = "update.skip"
    const val MARK_PROMPTED: String = "update.mark_prompted"
    const val SET_LOCALE: String = "update.set_locale"
    const val GET_RESOURCES: String = "update.get_resources"
}

/** The cross-platform update error codes. */
object FlareUpdateErrorCodes {
    const val MANIFEST_UNAVAILABLE: String = "update.manifestUnavailable"
    const val MANIFEST_REJECTED: String = "update.manifestRejected"
    const val NO_ARTIFACT: String = "update.noArtifact"
    const val METERED_CONFIRMATION_REQUIRED: String = "update.meteredConfirmationRequired"
    const val INSUFFICIENT_SPACE: String = "update.insufficientSpace"
    const val DOWNLOAD_FAILED: String = "update.downloadFailed"
    const val HASH_MISMATCH: String = "update.hashMismatch"
    const val INSTALL_FAILED: String = "update.installFailed"
    const val SIGNATURE_MISMATCH: String = "update.signatureMismatch"
    const val DOWNGRADE_REJECTED: String = "update.downgradeRejected"
    const val NOT_SKIPPABLE: String = "update.notSkippable"

    private val ALL = listOf(
        MANIFEST_UNAVAILABLE,
        MANIFEST_REJECTED,
        NO_ARTIFACT,
        METERED_CONFIRMATION_REQUIRED,
        INSUFFICIENT_SPACE,
        DOWNLOAD_FAILED,
        HASH_MISMATCH,
        INSTALL_FAILED,
        SIGNATURE_MISMATCH,
        DOWNGRADE_REJECTED,
        NOT_SKIPPABLE,
    )

    /** The code [text] names, null when it names none: `update.install` raises the code as its error text. */
    fun named(text: String?): String? = text?.let { value -> ALL.firstOrNull { code -> value.contains(code) } }
}

/** Where the update flow stands; [wireValue] is the SDK wire value. */
enum class FlareUpdateState(val wireValue: String) {
    IDLE("idle"),
    CHECKING("checking"),
    UP_TO_DATE("upToDate"),
    AVAILABLE("available"),
    REQUIRED("required"),
    DOWNLOADING("downloading"),
    VERIFYING("verifying"),
    READY_TO_INSTALL("readyToInstall"),
    INSTALLING("installing"),
    FAILED("failed"),
    ;

    companion object {
        fun fromWire(value: String?): FlareUpdateState? = entries.firstOrNull { it.wireValue == value }
    }
}

/** How the update should be put in front of the user. */
enum class FlareUpdatePromptForm(val wireValue: String) {
    NONE("none"),
    BADGE("badge"),
    SHEET("sheet"),
    MODAL("modal"),
    FULLSCREEN("fullscreen"),
    ;

    /** The forms that interrupt the user, as opposed to a quiet badge. */
    val interrupts: Boolean get() = this == SHEET || this == MODAL || this == FULLSCREEN

    companion object {
        fun fromWire(value: String?): FlareUpdatePromptForm? = entries.firstOrNull { it.wireValue == value }
    }
}

/** How a release reaches the device. */
enum class FlareUpdateKind(val wireValue: String) {
    STORE("store"),
    PACKAGE("package"),
    WEB_BUNDLE("webBundle"),
    DESKTOP("desktop"),
    ;

    companion object {
        fun fromWire(value: String?): FlareUpdateKind? = entries.firstOrNull { it.wireValue == value }
    }
}

/** Where a failed update sends the user instead: the Kit words its fallback button by this. */
enum class FlareUpdateFallbackTarget(val wireValue: String) {
    WEBSITE("website"),
    STORE("store"),
}

/** The installed app, as the engine knows it. */
data class FlareUpdateCurrent(
    val version: String? = null,
    val build: Long? = null,
    val channel: String? = null,
    val distribution: String? = null,
)

/** The release on offer. [notes] are already in the app's language. */
data class FlareUpdateRelease(
    val releaseId: String,
    val version: String,
    val build: Long,
    val notes: List<String> = emptyList(),
    /** Null for a store release: the store knows the size, the manifest does not. */
    val sizeBytes: Long? = null,
    val mandatory: Boolean = false,
    val recommended: Boolean = false,
    val kind: FlareUpdateKind,
)

/** Download progress in bytes. */
data class FlareUpdateProgress(val received: Long, val total: Long?)

/** A resource pack of this run. It is data for the Kit, so [contentJson] stays the text the engine verified. */
data class FlareUpdateResourcePack(
    val id: String,
    val kind: String,
    val packVersion: Long,
    val contentJson: String,
)

/** The last failure. */
data class FlareUpdateError(
    val code: String,
    val retryable: Boolean = false,
    val fallbackUrl: String? = null,
)

/** The `update://state` payload, and what every `update.*` route except `update.install` returns. */
data class FlareUpdateStatus(
    val state: FlareUpdateState,
    val current: FlareUpdateCurrent = FlareUpdateCurrent(),
    val release: FlareUpdateRelease? = null,
    val progress: FlareUpdateProgress? = null,
    val prompt: FlareUpdatePromptForm = FlareUpdatePromptForm.NONE,
    val blockUi: Boolean = false,
    val readOnly: Boolean = false,
    /** Why this build is blocked, in the app's language; null when it is not. */
    val blockReason: String? = null,
    /** Milliseconds; null when no check has run yet. */
    val lastCheckedAt: Long? = null,
    val error: FlareUpdateError? = null,
) {
    /** The direct channel falls back to the website, every other channel to its store. */
    val fallbackTarget: FlareUpdateFallbackTarget
        get() = if (current.distribution == DIRECT_DISTRIBUTION) {
            FlareUpdateFallbackTarget.WEBSITE
        } else {
            FlareUpdateFallbackTarget.STORE
        }

    /**
     * A forced update that does not block the UI can be put aside to browse read only. The state says
     * forced on its own: when the server refuses this build before the manifest arrives, [release] is null.
     */
    val canContinueReadOnly: Boolean
        get() = (state == FlareUpdateState.REQUIRED || release?.mandatory == true) && !blockUi

    private companion object {
        const val DIRECT_DISTRIBUTION = "direct"
    }
}

/** What the platform is asked to do; the engine decides it, the installer only carries it out. */
sealed interface FlareUpdateInstallPlan {
    /** Opens a store, or the website when [store] is [WEBSITE]. */
    data class OpenStore(
        val store: String,
        val url: String? = null,
        val packageName: String? = null,
        val appId: String? = null,
        /** Play only: run the immediate flow rather than the flexible one. */
        val immediate: Boolean = false,
    ) : FlareUpdateInstallPlan {
        companion object {
            /** The value of [store] for a plain link: no store app is involved. */
            const val WEBSITE: String = "website"
        }
    }

    /** Installs a verified download. */
    data class InstallPackage(
        val path: String,
        val sha256: String,
        val signingCertSha256: String,
        val build: Long,
        val sizeBytes: Long,
    ) : FlareUpdateInstallPlan

    /** A plan for another platform; Android cannot carry it out. */
    data class Unsupported(val kind: String) : FlareUpdateInstallPlan
}

/** The values `update.report_install` takes. */
enum class FlareUpdateOutcome(val wireValue: String) {
    STARTED("started"),
    COMPLETED("completed"),
    CANCELLED("cancelled"),
    FAILED("failed"),
}

/**
 * What became of a plan. `completed` means nothing is left to do here: for a store that its page
 * opened, whether the user installs being the store's business. `started` means work goes on in the
 * background and [FlareUpdateInstaller.handoff] tells how it ends. [code] is set on `failed`.
 */
data class FlareUpdateInstallResult(val outcome: FlareUpdateOutcome, val code: String? = null) {
    companion object {
        fun failed(code: String): FlareUpdateInstallResult = FlareUpdateInstallResult(FlareUpdateOutcome.FAILED, code)
    }
}

/** A route refused the call. [code] is the cross-platform code when the engine gave one. */
class FlareUpdateException(
    val code: String,
    message: String? = null,
    val retryable: Boolean = false,
    val fallbackUrl: String? = null,
    cause: Throwable? = null,
) : Exception(message ?: code, cause)
