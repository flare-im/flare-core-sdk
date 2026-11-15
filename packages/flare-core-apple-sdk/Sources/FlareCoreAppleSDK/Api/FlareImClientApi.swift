import Foundation

/// GENERATED. Do not edit by hand.
public struct AnySendable: @unchecked Sendable { public let value: Any; public init(_ value: Any) { self.value = value } }

public protocol FlareImClientProtocol: SessionApiProtocol {
    var connection: any ConnectionApiProtocol { get }
    var access: any AccessApiProtocol { get }
    var lifecycle: any LifecycleApiProtocol { get }
    var update: any UpdateApiProtocol { get }
    var conversations: any ConversationsApiProtocol { get }
    var messageBuilder: any MessageBuilderApiProtocol { get }
    var messages: any MessagesApiProtocol { get }
    var sync: any SyncApiProtocol { get }
    var user: any UserApiProtocol { get }
    var presence: any PresenceApiProtocol { get }
    var media: any MediaApiProtocol { get }
    var capabilities: any CapabilitiesApiProtocol { get }
    var views: any ViewsApiProtocol { get }
    var events: any EventsApiProtocol { get }
    var diagnostics: any DiagnosticsApiProtocol { get }
    var notification: any NotificationApiProtocol { get }
}
