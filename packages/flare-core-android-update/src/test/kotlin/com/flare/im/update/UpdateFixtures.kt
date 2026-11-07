package com.flare.im.update

import java.util.Collections
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

internal fun wireRelease(
    kind: String = "package",
    build: Long = 20400,
    mandatory: Boolean = false,
): Map<String, Any?> = mapOf(
    "releaseId" to "rel_01JC8W",
    "version" to "2.4.0",
    "build" to build,
    "notes" to listOf("Scheduled messages"),
    "sizeBytes" to 52428800L,
    "mandatory" to mandatory,
    "recommended" to false,
    "kind" to kind,
)

internal fun status(
    state: String,
    release: Map<String, Any?>? = wireRelease(),
    prompt: String = "none",
    blockUi: Boolean = false,
    readOnly: Boolean = false,
    blockReason: String? = null,
    error: Map<String, Any?>? = null,
    distribution: String = "direct",
): Map<String, Any?> = mapOf(
    "state" to state,
    "current" to mapOf("version" to "2.3.2", "build" to 20302L, "channel" to "stable", "distribution" to distribution),
    "release" to release,
    "progress" to null,
    "prompt" to prompt,
    "blockUi" to blockUi,
    "readOnly" to readOnly,
    "blockReason" to blockReason,
    "lastCheckedAt" to null,
    "error" to error,
)

internal val PACKAGE_PLAN: Map<String, Any?> = mapOf(
    "kind" to "installPackage",
    "path" to "/data/cache/2.4.0-20400.apk",
    "sha256" to "aa",
    "signingCertSha256" to "bb",
    "build" to 20400L,
    "sizeBytes" to 52428800L,
)

/** Answers each route with what the test set, and records every call. */
internal class FakeEngine : FlareUpdateEngine {
    val calls: MutableList<Pair<String, Map<String, Any?>>> = Collections.synchronizedList(mutableListOf())
    val answers: MutableMap<String, Map<String, Any?>> = mutableMapOf()
    val refusals: MutableMap<String, FlareUpdateException> = mutableMapOf()
    val failures: MutableMap<String, Exception> = mutableMapOf()
    private var listener: ((Map<String, Any?>) -> Unit)? = null
    var closed = false

    override suspend fun dispatch(operation: String, params: Map<String, Any?>): Map<String, Any?> {
        calls += operation to params
        refusals.remove(operation)?.let { throw it }
        failures.remove(operation)?.let { throw it }
        return answers[operation] ?: answers.getValue(FlareUpdateOperations.GET_STATE)
    }

    override fun subscribeState(onState: (Map<String, Any?>) -> Unit): AutoCloseable {
        listener = onState
        return AutoCloseable { closed = true }
    }

    fun emit(payload: Map<String, Any?>) {
        listener?.invoke(payload)
    }

    fun routes(): List<String> = calls.map { it.first }

    fun count(operation: String): Int = calls.count { it.first == operation }
}

internal class FakeInstaller(
    var result: FlareUpdateInstallResult = FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED),
    var prompts: Boolean = true,
) : FlareUpdateInstaller {
    val executed: MutableList<FlareUpdateInstallPlan> = mutableListOf()
    val handoffs = MutableStateFlow(FlareUpdateHandoff.NONE)
    var completed = 0

    /** When set, [execute] stays open until the test ends it, as a session waiting for the user does. */
    var waitsFor: CompletableDeferred<FlareUpdateInstallResult>? = null

    override suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult {
        executed += plan
        return waitsFor?.await() ?: result
    }

    override suspend fun canPrompt(release: FlareUpdateRelease): Boolean = prompts

    override val handoff: StateFlow<FlareUpdateHandoff> get() = handoffs

    override suspend fun completeHandoff(): FlareUpdateInstallResult {
        completed += 1
        return FlareUpdateInstallResult(FlareUpdateOutcome.COMPLETED)
    }
}

internal class FakeForeground : FlareUpdateForegroundSource {
    private var listener: (() -> Unit)? = null
    val listening: Boolean get() = listener != null

    override fun start(onForeground: () -> Unit): AutoCloseable {
        listener = onForeground
        return AutoCloseable { listener = null }
    }

    fun emit() {
        listener?.invoke()
    }
}
