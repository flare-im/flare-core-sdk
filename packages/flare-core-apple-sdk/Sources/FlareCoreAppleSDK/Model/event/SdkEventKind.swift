import Foundation

/// GENERATED. Do not edit by hand.
/// Top-level event domain.
public enum SdkEventKind: String, Codable, Sendable {
    case lifecycle = "lifecycle"
    case connection = "connection"
    case message = "message"
    case notification = "notification"
    case conversation = "conversation"
    case sync = "sync"
    case `extension` = "extension"
    case extensionEvent = "extension_event"
    case presence = "presence"
    case media = "media"
    case plugin = "plugin"
    case view = "view"
}
