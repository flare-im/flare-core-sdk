package com.flare.im.update.ui

import com.flare.im.ui.FlareResourcePack
import com.flare.im.ui.FlareStrings
import com.flare.im.update.FlareUpdateController
import com.flare.im.update.FlareUpdateEngine
import com.flare.im.update.FlareUpdateForegroundSource
import com.flare.im.update.FlareUpdateInstallPlan
import com.flare.im.update.FlareUpdateInstallResult
import com.flare.im.update.FlareUpdateInstaller
import com.flare.im.update.FlareUpdateOperations
import com.flare.im.update.FlareUpdateOutcome
import com.flare.im.update.FlareUpdateResourcePack
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private const val STRINGS_PACK =
    """{"schema":"flare.resource.v1","kind":"strings","locales":{"en":{"send":"Send it"}}}"""

/** Answers the status and the packs; counts how often the packs are read. */
private class PackEngine(private val packs: List<Map<String, Any?>>) : FlareUpdateEngine {
    var reads = 0

    override suspend fun dispatch(operation: String, params: Map<String, Any?>): Map<String, Any?> =
        if (operation == FlareUpdateOperations.GET_RESOURCES) {
            reads += 1
            mapOf("packs" to packs)
        } else {
            mapOf("state" to "idle")
        }

    override fun subscribeState(onState: (Map<String, Any?>) -> Unit): AutoCloseable = AutoCloseable {}
}

private object NoInstaller : FlareUpdateInstaller {
    override suspend fun execute(plan: FlareUpdateInstallPlan): FlareUpdateInstallResult =
        FlareUpdateInstallResult(FlareUpdateOutcome.CANCELLED)
}

@OptIn(ExperimentalCoroutinesApi::class)
class FlareUpdateResourcesTest {
    private val stringsPack = mapOf(
        "id" to "strings",
        "kind" to "strings",
        "packVersion" to 3L,
        "contentJson" to STRINGS_PACK,
    )

    private fun controller(engine: FlareUpdateEngine, scope: CoroutineScope) = FlareUpdateController(
        engine,
        NoInstaller,
        foreground = FlareUpdateForegroundSource { AutoCloseable {} },
        scope = scope,
    )

    @Test
    fun aPackReachesTheKitAsIs() {
        val pack = FlareUpdateResourcePack("strings", "strings", 3, STRINGS_PACK)
        assertEquals(FlareResourcePack("strings", "strings", 3, STRINGS_PACK), pack.kitPack)
    }

    /** `update.*` needs `init`, and the first status is what says the engine is up. */
    @Test
    fun theOverlayWaitsForTheEngine() = runTest {
        val engine = PackEngine(listOf(stringsPack))
        val controller = controller(engine, backgroundScope)

        val loading = async { loadResourceOverlay(controller) }
        runCurrent()
        assertEquals(0, engine.reads)

        controller.install()
        val overlay = loading.await()

        assertEquals(1, engine.reads)
        assertFalse(overlay.isEmpty)
        assertEquals("Send it", overlay.strings(FlareStrings(), locale = "en").send)
    }

    @Test
    fun noPacksLeaveTheBuiltInResources() = runTest {
        val controller = controller(PackEngine(emptyList()), backgroundScope).install()
        assertTrue(loadResourceOverlay(controller).isEmpty)
    }
}
