#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation

/// Native side of the Flare update center on iOS and macOS: runs install plans through the
/// `FlarePlatformUpdate` installer, whose sources are linked in next to this file. The update flow
/// stays in the engine and the Dart controller.
///
/// Method channel `flare_core_flutter_update`: `execute` takes a plan and answers `{outcome, code}`.
/// `canPrompt` and `completeHandoff` answer for a platform whose store has nothing to ask and nothing
/// to hand back.
public final class FlareCoreFlutterUpdatePlugin: NSObject, FlutterPlugin {
    private let installer: FlareUpdateInstaller = FlareSystemUpdateInstaller()

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let instance = FlareCoreFlutterUpdatePlugin()
        let methods = FlutterMethodChannel(name: "flare_core_flutter_update", binaryMessenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: methods)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "execute":
            guard let wire = call.arguments as? [String: Any],
                  let plan = try? FlareUpdateInstallPlan(wire: wire) else {
                result(FlutterError(code: "update", message: "not an update plan", details: nil))
                return
            }
            Task { @MainActor in
                let outcome = await installer.execute(plan)
                result(outcome.reportParams)
            }
        case "canPrompt":
            result(true)
        case "completeHandoff":
            result(FlareUpdateInstallResult(outcome: .cancelled).reportParams)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
