package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// The host's answer to a plugin.capability_request event.
public class PluginCapabilityCompletion {
    // wire: `requestId`. The event's requestId.
    public let requestId: UInt64
    // wire: `result`. Optional. consent: {granted}; captureDocument and pickFile: {file: {fileName, contentType, bytes: [0..255]}} (a document photo compressed, without EXIF); confirmPayment: {confirmation: {...}} (the proof the order's operation takes, at most 4 KiB); locateOnce: {location: {latitude, longitude, accuracyM?}}. Any of them may instead be {cancelled: true} (the viewer backed out) or {unavailable: true} (the host could not); absent counts as unavailable.
    public let result: ?String

    public init(requestId!: UInt64, result!: ?String) {
        this.requestId = requestId
        this.result = result
    }
}
