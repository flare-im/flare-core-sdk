import Foundation

/// GENERATED. Do not edit by hand.
/// Connection status and manual network lifecycle.
public protocol ConnectionApiProtocol: AnyObject {
    func getStatus() async throws -> ConnectionStatus
    func reconnectNow() async throws -> Void
    func disconnect() async throws -> Void
    func getServerClock() async throws -> ServerClockResponse
    func notifyNetworkChange(_ request: NetworkChangeRequest) async throws -> Void
}
