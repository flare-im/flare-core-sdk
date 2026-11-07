package com.flare.im.update.flutter

import android.app.Activity
import android.content.Context
import com.flare.im.update.FlareUpdateCodec
import com.flare.im.update.FlareUpdateInstaller
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Native side of the Flare update center on Android: runs install plans through
 * `flare-core-android-update`, which holds every check. The update flow stays in the engine and the
 * Dart controller.
 *
 * - Method channel `flare_core_flutter_update`: `execute` takes a plan and answers `{outcome, code}`,
 *   `canPrompt` takes a release and answers a bool, `completeHandoff` answers `{outcome, code}`.
 * - Event channel `flare_core_flutter_update/handoff`: what a store does with an update it took over.
 */
class FlareCoreFlutterUpdatePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var installer: FlareUpdateInstaller? = null
    private var activity: Activity? = null
    private var scope: CoroutineScope? = null
    private var handoffJob: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        installer = installerFactory(binding.applicationContext) { activity }
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        events = EventChannel(binding.binaryMessenger, HANDOFF_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        scope?.cancel()
        methods = null
        events = null
        scope = null
        installer = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val installer = installer
        if (installer == null) {
            result.error("unavailable", "plugin is detached", null)
            return
        }
        when (call.method) {
            "execute" -> answer(result) {
                FlareUpdateCodec.reportParams(installer.execute(FlareUpdateCodec.plan(arguments(call))))
            }
            "canPrompt" -> answer(result) {
                installer.canPrompt(FlareUpdateCodec.release(arguments(call)))
            }
            "completeHandoff" -> answer(result) {
                FlareUpdateCodec.reportParams(installer.completeHandoff())
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val installer = installer ?: return
        handoffJob?.cancel()
        handoffJob = scope?.launch {
            installer.handoff.collect { handoff -> sink.success(handoff.wireValue) }
        }
    }

    override fun onCancel(arguments: Any?) {
        handoffJob?.cancel()
        handoffJob = null
    }

    private fun answer(result: MethodChannel.Result, work: suspend () -> Any?) {
        val scope = scope
        if (scope == null) {
            result.error("unavailable", "plugin is detached", null)
            return
        }
        scope.launch {
            try {
                result.success(work())
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                result.error("update", failure.message, null)
            }
        }
    }

    private fun arguments(call: MethodCall): Map<String, Any?> =
        (call.arguments as? Map<*, *>)?.entries?.associate { (key, value) -> key.toString() to value } ?: emptyMap()

    companion object {
        private const val METHOD_CHANNEL = "flare_core_flutter_update"
        private const val HANDOFF_CHANNEL = "flare_core_flutter_update/handoff"

        /**
         * Builds the installer. A Play flavor sets this to a `FlarePlayUpdateInstaller` before the engine
         * attaches, in its `Application.onCreate`; the plugin itself carries no Play code. The second
         * argument gives the activity on screen.
         */
        @JvmStatic
        var installerFactory: (Context, () -> Activity?) -> FlareUpdateInstaller =
            { context, _ -> FlareUpdateInstaller.system(context) }
    }
}
