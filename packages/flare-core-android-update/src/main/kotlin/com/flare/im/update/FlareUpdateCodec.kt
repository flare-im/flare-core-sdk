package com.flare.im.update

import org.json.JSONArray
import org.json.JSONObject

/** Reads the update wire shapes from decoded JSON. A malformed payload throws [IllegalArgumentException]. */
object FlareUpdateCodec {
    fun status(map: Map<String, Any?>): FlareUpdateStatus = FlareUpdateStatus(
        state = required(FlareUpdateState.fromWire(map["state"] as? String), "state", map["state"]),
        current = current(map["current"]),
        release = (map["release"] as? Map<*, *>)?.let { release(stringKeyed(it)) },
        progress = progress(map["progress"]),
        prompt = FlareUpdatePromptForm.fromWire(map["prompt"] as? String) ?: FlareUpdatePromptForm.NONE,
        blockUi = map["blockUi"] == true,
        readOnly = map["readOnly"] == true,
        blockReason = map["blockReason"] as? String,
        lastCheckedAt = long(map["lastCheckedAt"]),
        error = error(map["error"]),
    )

    fun release(map: Map<String, Any?>): FlareUpdateRelease = FlareUpdateRelease(
        releaseId = required(map["releaseId"] as? String, "releaseId", map["releaseId"]),
        version = required(map["version"] as? String, "version", map["version"]),
        build = required(long(map["build"]), "build", map["build"]),
        notes = (map["notes"] as? List<*>).orEmpty().filterIsInstance<String>(),
        sizeBytes = long(map["sizeBytes"]),
        mandatory = map["mandatory"] == true,
        recommended = map["recommended"] == true,
        kind = required(FlareUpdateKind.fromWire(map["kind"] as? String), "kind", map["kind"]),
    )

    fun plan(map: Map<String, Any?>): FlareUpdateInstallPlan = when (val kind = map["kind"] as? String) {
        "openStore" -> FlareUpdateInstallPlan.OpenStore(
            store = required(map["store"] as? String, "store", map["store"]),
            url = map["url"] as? String,
            packageName = map["packageName"] as? String,
            appId = map["appId"] as? String,
            immediate = map["immediate"] == true,
        )
        "installPackage" -> FlareUpdateInstallPlan.InstallPackage(
            path = required(map["path"] as? String, "path", map["path"]),
            sha256 = required(map["sha256"] as? String, "sha256", map["sha256"]),
            signingCertSha256 = required(
                map["signingCertSha256"] as? String,
                "signingCertSha256",
                map["signingCertSha256"],
            ),
            build = required(long(map["build"]), "build", map["build"]),
            sizeBytes = required(long(map["sizeBytes"]), "sizeBytes", map["sizeBytes"]),
        )
        null -> throw IllegalArgumentException("update plan has no kind")
        else -> FlareUpdateInstallPlan.Unsupported(kind)
    }

    /** The packs of an `update.get_resources` answer. */
    fun resourcePacks(map: Map<String, Any?>): List<FlareUpdateResourcePack> =
        (map["packs"] as? List<*>).orEmpty().map { value ->
            val pack = (value as? Map<*, *>)?.let(::stringKeyed).orEmpty()
            FlareUpdateResourcePack(
                id = required(pack["id"] as? String, "pack.id", pack["id"]),
                kind = required(pack["kind"] as? String, "pack.kind", pack["kind"]),
                packVersion = required(long(pack["packVersion"]), "pack.packVersion", pack["packVersion"]),
                contentJson = required(pack["contentJson"] as? String, "pack.contentJson", pack["contentJson"]),
            )
        }

    /** The `update.report_install` parameters for [result]. */
    fun reportParams(result: FlareUpdateInstallResult): Map<String, Any?> = buildMap {
        put("outcome", result.outcome.wireValue)
        result.code?.let { put("code", it) }
    }

    private fun current(value: Any?): FlareUpdateCurrent {
        val map = (value as? Map<*, *>)?.let(::stringKeyed) ?: return FlareUpdateCurrent()
        return FlareUpdateCurrent(
            version = map["version"] as? String,
            build = long(map["build"]),
            channel = map["channel"] as? String,
            distribution = map["distribution"] as? String,
        )
    }

    private fun progress(value: Any?): FlareUpdateProgress? {
        val map = (value as? Map<*, *>)?.let(::stringKeyed) ?: return null
        return FlareUpdateProgress(received = long(map["received"]) ?: 0L, total = long(map["total"]))
    }

    private fun error(value: Any?): FlareUpdateError? {
        val map = (value as? Map<*, *>)?.let(::stringKeyed) ?: return null
        return FlareUpdateError(
            code = required(map["code"] as? String, "error.code", map["code"]),
            retryable = map["retryable"] == true,
            fallbackUrl = map["fallbackUrl"] as? String,
        )
    }

    private fun long(value: Any?): Long? = (value as? Number)?.toLong()

    private fun stringKeyed(map: Map<*, *>): Map<String, Any?> =
        map.entries.associate { (key, item) -> key.toString() to item }

    private fun <T : Any> required(value: T?, field: String, raw: Any?): T =
        requireNotNull(value) { "update payload has a bad $field: $raw" }
}

/** This object as the plain maps and lists the update port speaks, for hosts that hold `org.json` values. */
fun JSONObject.toFlareUpdateMap(): Map<String, Any?> =
    keys().asSequence().associateWith { key -> plainValue(get(key)) }

private fun plainValue(value: Any?): Any? = when {
    value == null || value == JSONObject.NULL -> null
    value is JSONObject -> value.toFlareUpdateMap()
    value is JSONArray -> (0 until value.length()).map { index -> plainValue(value.get(index)) }
    else -> value
}
