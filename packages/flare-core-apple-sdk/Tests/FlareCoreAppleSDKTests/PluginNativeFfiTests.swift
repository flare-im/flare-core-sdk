import Foundation
import XCTest
import FlareCoreAppleSDK

/// Invoked explicitly by verify-plugin-native-ffi.py with an owned loopback
/// fixture. Normal tests skip when no actual library has been supplied.
final class PluginNativeFfiTests: XCTestCase {
    func testActualNativePreparationAndPluginDispatch() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let library = environment["FLARE_PLUGIN_TEST_FFI_LIBRARY"],
              let gateway = environment["FLARE_PLUGIN_TEST_HTTP_URL"] else {
            throw XCTSkip("requires an explicitly built native library and owned HTTP fixture")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("flare-plugin-swift-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = try FfiNativeBridge(libraryPath: library)
        let api = DefaultCapabilitiesApi(bridge: bridge)
        do {
            // Development access: the fixture is the Core API; the IM endpoint is never reached.
            _ = try await bridge.invoke(NativeCallMap.sdkInit, request: AnySendable([
                "dataUrl": directory.absoluteString, "tenantId": "201",
                "access": ["trustMode": "development", "developmentEndpoints": ["coreApiUrl": gateway, "quicUrl": "quic://127.0.0.1:1"]],
            ] as [String: Any]))
            do {
                _ = try await bridge.invoke(NativeCallMap.sdkConnect, request: AnySendable(["userId": "u1"]))
                XCTFail("connect before preparation must fail")
            } catch let error as FlareSdkException {
                XCTAssertNotEqual(error.code, "unsupported_operation", "connect must reach the actual C ABI guard")
            }
            _ = try await bridge.invoke(NativeCallMap.sdkPrepare, request: AnySendable(["userId": "u1"]))
            let message: [String: Any] = ["pluginId": "example.poll", "contributionId": "example.poll.card", "schemaVersion": 1,
                "summary": "Poll history", "payload": ["pollId": "poll-1", "question": "Question", "tenantId": "forged"]]
            for platform in ["web", "tauri", "android", "ios", "flutter", "harmonyos"] {
                let view = try await api.presentPluginMessage(PluginUiEvaluationRequest(payload: [
                    "message": AnySendable(message), "platform": AnySendable(platform), "locale": AnySendable("en-US"),
                ]))
                XCTAssertEqual(view["available"]?.value as? Bool, true)
                XCTAssertEqual(view["title"]?.value as? String, "Poll")
                let response = try await api.invokePluginAction(PluginUiEvaluationRequest(payload: [
                    "message": AnySendable(message), "platform": AnySendable(platform), "actionId": AnySendable("vote"),
                    "conversationId": AnySendable("conversation-1"), "userGesture": AnySendable(true), "nativeAllowlist": AnySendable([String]()),
                ]))
                XCTAssertEqual(response["kind"]?.value as? String, "operation")
            }
            _ = try await api.preparePluginCommand(PluginCommandRequest(payload:["slot":AnySendable("example.create"),"command":AnySendable(["commandId":"stable-swift-command","capabilityId":"example.poll.vote","conversationId":"conversation-1","payload":["pollId":"poll-1"]] as [String:Any])]))
            let submit=PluginCommandRequest(payload:["slot":AnySendable("example.create"),"commandId":AnySendable("stable-swift-command")])
            do { _ = try await api.acknowledgePluginCommand(submit); XCTFail("unknown command cannot be cleared") } catch { }
            let completed=try await api.submitPluginCommand(submit)
            XCTAssertEqual((completed["response"]?.value as? [String:Any])?["success"] as? Bool,true)
            let replay=try await api.submitPluginCommand(submit)
            XCTAssertEqual((replay["command"]?.value as? [String:Any])?["commandId"] as? String,"stable-swift-command")
            _ = try await api.acknowledgePluginCommand(submit)
            _ = try await api.preparePluginCommand(PluginCommandRequest(payload:["slot":AnySendable("observe"),"command":AnySendable(["commandId":"observed-swift","capabilityId":"example.poll.vote","reconciliationCapabilityId":"example.poll.lookup","conversationId":"conversation-1","payload":["commandId":"observed-swift","pollId":"poll-1"]] as [String:Any])]))
            let lookup=PluginCommandRequest(payload:["slot":AnySendable("observe"),"commandId":AnySendable("observed-swift")])
            let observation=try await api.reconcilePluginCommand(lookup)
            XCTAssertEqual(observation["outcome"]?.value as? String,"committed")
            let observedReplay=try await api.submitPluginCommand(lookup)
            XCTAssertEqual((observedReplay["response"]?.value as? [String:Any])?["data"] as? [String:String],["status":"observed"])
            _ = try await api.acknowledgePluginCommand(lookup)

            _ = try await bridge.invoke(NativeCallMap.sdkLogout, request: nil)
            do { _ = try await api.pendingPluginCommand(PluginCommandRequest(payload:["slot":AnySendable("example.create")])); XCTFail("logout must fence journal reads") } catch { }
            do {
                _ = try await api.presentPluginMessage(PluginUiEvaluationRequest(payload: ["message": AnySendable(message), "platform": AnySendable("ios")]))
                XCTFail("logged-out native adapter must reject plugin reads")
            } catch { /* expected session fence */ }
        } catch {
            _ = try? await bridge.invoke(NativeCallMap.sdkUninit, request: nil)
            _ = try? await bridge.invoke(NativeCallMap.sdkDispose, request: nil)
            throw error
        }
        _ = try await bridge.invoke(NativeCallMap.sdkUninit, request: nil)
        _ = try await bridge.invoke(NativeCallMap.sdkDispose, request: nil)
    }
}
