import Foundation

/// GENERATED. Do not edit by hand.
/// PushTokenInput
public struct PushTokenInput: Codable, Sendable {
    /// wire: `appBundle`. iOS bundle id or Android applicationId. The server sends APNs to this topic.
    public let appBundle: String?
    /// wire: `appVersion`. App version string.
    public let appVersion: String?
    /// wire: `capabilities`. What the app can do with a push: dataMessages (Android FCM data messages) and serviceExtension (iOS notification service extension). Unknown values are rejected.
    public let capabilities: [String]?
    /// wire: `environment`. APNs only: sandbox or production, the APNs host the token belongs to.
    public let environment: String?
    /// wire: `locale`. BCP 47 language tag the server renders notification text in, e.g. zh-CN.
    public let locale: String?
    /// wire: `platform`. Native platform: android, ios or harmony.
    public let platform: String
    /// wire: `provider`. OS delivery provider: fcm, apns or getui.
    public let provider: String
    /// wire: `timeZone`. IANA time zone, e.g. Asia/Shanghai.
    public let timeZone: String?
    /// wire: `token`. OS-issued token. Never log or persist outside protected native storage.
    public let token: String

    public init(appBundle: String? = nil, appVersion: String? = nil, capabilities: [String]? = nil, environment: String? = nil, locale: String? = nil, platform: String = "", provider: String = "", timeZone: String? = nil, token: String = "") {
        self.appBundle = appBundle
        self.appVersion = appVersion
        self.capabilities = capabilities
        self.environment = environment
        self.locale = locale
        self.platform = platform
        self.provider = provider
        self.timeZone = timeZone
        self.token = token
    }
}
