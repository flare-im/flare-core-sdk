package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// PushTokenInput
public class PushTokenInput {
    // wire: `appBundle`. Optional. iOS bundle id or Android applicationId. The server sends APNs to this topic.
    public let appBundle: ?String
    // wire: `appVersion`. Optional. App version string.
    public let appVersion: ?String
    // wire: `capabilities`. Optional. What the app can do with a push: dataMessages (Android FCM data messages) and serviceExtension (iOS notification service extension). Unknown values are rejected.
    public let capabilities: ?String
    // wire: `environment`. Optional. APNs only: sandbox or production, the APNs host the token belongs to.
    public let environment: ?String
    // wire: `locale`. Optional. BCP 47 language tag the server renders notification text in, e.g. zh-CN.
    public let locale: ?String
    // wire: `platform`. Native platform: android, ios or harmony.
    public let platform: String
    // wire: `provider`. OS delivery provider: fcm, apns or getui.
    public let provider: String
    // wire: `timeZone`. Optional. IANA time zone, e.g. Asia/Shanghai.
    public let timeZone: ?String
    // wire: `token`. OS-issued token. Never log or persist outside protected native storage.
    public let token: String

    public init(appBundle!: ?String, appVersion!: ?String, capabilities!: ?String, environment!: ?String, locale!: ?String, platform!: String, provider!: String, timeZone!: ?String, token!: String) {
        this.appBundle = appBundle
        this.appVersion = appVersion
        this.capabilities = capabilities
        this.environment = environment
        this.locale = locale
        this.platform = platform
        this.provider = provider
        this.timeZone = timeZone
        this.token = token
    }
}
