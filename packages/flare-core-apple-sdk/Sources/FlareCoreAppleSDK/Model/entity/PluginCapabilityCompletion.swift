import Foundation

/// GENERATED. Do not edit by hand.
/// The host's answer to a plugin.capability_request event.
public struct PluginCapabilityCompletion: Sendable {
    /// wire: `requestId`. The event's requestId.
    public let requestId: UInt64
    /// wire: `result`. consent: {granted}; captureDocument and pickFile: {file: {fileName, contentType, bytes: [0..255]}} (a document photo compressed, without EXIF); confirmPayment: {confirmation: {...}} (the proof the order's operation takes, at most 4 KiB); locateOnce: {location: {latitude, longitude, accuracyM?}}. Any of them may instead be {cancelled: true} (the viewer backed out) or {unavailable: true} (the host could not); absent counts as unavailable.
    public let result: [String: AnySendable]?

    public init(requestId: UInt64 = 0, result: [String: AnySendable]? = nil) {
        self.requestId = requestId
        self.result = result
    }
}
