package com.flare.im.lifecycle

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of the Flare Core platform lifecycle.
 *
 * - Method channel `flare_core_flutter_lifecycle`: `appInfo` answers
 *   `{version, build, distribution}` from `PackageManager`.
 * - Event channel `flare_core_flutter_lifecycle/network`: network readings
 *   `{available, interface, metered, fingerprintHint}` from the default network
 *   callback, the current network first.
 */
class FlareCoreFlutterLifecyclePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private var context: Context? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var monitor: NetworkMonitor? = null
    private val mainThread = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        events = EventChannel(binding.binaryMessenger, NETWORK_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        stopMonitor()
        methods = null
        events = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context
        when {
            context == null -> result.error("unavailable", "plugin is detached", null)
            call.method == "appInfo" -> result.success(AppInfoReader.read(context))
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val context = context ?: return
        stopMonitor()
        val listening = ++generation
        monitor = NetworkMonitor(context) { reading ->
            // Callbacks arrive on a connectivity thread; the sink lives on the main thread.
            // Readings of a listener that has since been cancelled are dropped.
            mainThread.post {
                if (listening == generation && monitor != null) sink.success(reading)
            }
        }.also { it.start() }
    }

    override fun onCancel(arguments: Any?) {
        stopMonitor()
    }

    /** Bumped on every listen and cancel. */
    private var generation = 0

    private fun stopMonitor() {
        generation++
        monitor?.stop()
        monitor = null
    }

    private companion object {
        const val METHOD_CHANNEL = "flare_core_flutter_lifecycle"
        const val NETWORK_CHANNEL = "flare_core_flutter_lifecycle/network"
    }
}
