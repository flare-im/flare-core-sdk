package com.flare.im.update.ui

import android.util.Log
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.flare.im.ui.FlareResourceOverlay
import com.flare.im.ui.FlareResourcePack
import com.flare.im.ui.FlareThemeMode
import com.flare.im.ui.FlareThemeProvider
import com.flare.im.ui.LocalFlareStrings
import com.flare.im.ui.flareColors
import com.flare.im.ui.flareThemeIsDark
import com.flare.im.update.FlareUpdateController
import com.flare.im.update.FlareUpdateResourcePack
import java.util.WeakHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext

/**
 * The overlay of each controller. A controller outlives its activity, and a rotation should not put the built-in
 * resources back for a frame. The packs do not change during a run, so one read holds. Main thread only.
 */
private val loadedOverlays = WeakHashMap<FlareUpdateController, FlareResourceOverlay>()

/** The pack as the Kit takes it. */
val FlareUpdateResourcePack.kitPack: FlareResourcePack
    get() = FlareResourcePack(id, kind, packVersion, contentJson)

/** This run's overlay, once the engine is up: the first status says so. No packs make an empty one. */
internal suspend fun loadResourceOverlay(controller: FlareUpdateController): FlareResourceOverlay {
    controller.state.filterNotNull().first()
    val packs = controller.loadResources()
    if (packs.isEmpty()) return FlareResourceOverlay.Empty
    // A pack can run to megabytes, and no frame should wait for it.
    return withContext(Dispatchers.Default) { FlareResourceOverlay(packs.map { it.kitPack }) }
}

/**
 * Puts this run's resource packs over the Kit's built-in strings, colours and emoji for [content]. The built-in
 * resources render first and the overlay replaces them when it arrives; when it cannot be read they simply stay, and
 * the controller's `onError` has the reason.
 *
 * Put it once at the root, inside the theme and the strings it goes over. [locale] is the language of those strings
 * and [mode] the one the theme was given. [onOverlay] hears of the overlay when it arrives, for what reads no Kit
 * local: the app's own strings, copy a view model formats. It hears again after a rotation, with the same overlay.
 */
@Composable
fun FlareUpdateResourceScope(
    controller: FlareUpdateController,
    locale: String,
    mode: FlareThemeMode = FlareThemeMode.System,
    onOverlay: (FlareResourceOverlay) -> Unit = {},
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current.applicationContext
    val overlay by produceState(loadedOverlays[controller] ?: FlareResourceOverlay.Empty, controller) {
        loadedOverlays[controller]?.let { held ->
            onOverlay(held)
            return@produceState
        }
        val loaded = loadResourceOverlay(controller)
        if (loaded.isEmpty) return@produceState
        value = loaded
        onOverlay(loaded)
        try {
            loaded.registerEmoji(context)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            Log.w("FlareUpdate", "resource emoji not registered", failure)
        }
        loadedOverlays[controller] = loaded
    }
    // LocalFlareStrings is a static local: a new object here would recompose the whole app.
    val baseStrings = LocalFlareStrings.current
    val strings = remember(overlay, baseStrings, locale) { overlay.strings(baseStrings, locale = locale) }
    val dark = flareThemeIsDark(mode, isSystemInDarkTheme())
    val baseColors = flareColors()
    val colors = remember(overlay, baseColors, dark) { overlay.colors(baseColors, dark) }
    CompositionLocalProvider(LocalFlareStrings provides strings) {
        FlareThemeProvider(mode = mode, colors = colors, content = content)
    }
}
