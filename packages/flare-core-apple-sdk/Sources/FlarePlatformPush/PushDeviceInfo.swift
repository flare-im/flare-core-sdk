import Foundation
import FlarePlatformLifecycle

/// 随令牌登记的应用信息。语言、时区、版本在进程活着时也会变，每次回到前台重新读，变了就重新登记。
public struct PlatformPushDeviceInfo: Equatable, Sendable {
    public var appBundle: String?
    /// `sandbox` 或 `production`。
    public var environment: String?
    public var locale: String?
    public var timeZone: String?
    public var appVersion: String?

    public init(
        appBundle: String? = nil,
        environment: String? = nil,
        locale: String? = nil,
        timeZone: String? = nil,
        appVersion: String? = nil
    ) {
        self.appBundle = appBundle
        self.environment = environment
        self.locale = locale
        self.timeZone = timeZone
        self.appVersion = appVersion
    }

    /// 主 bundle 的包名与版本、系统首选语言、当前时区，以及这个构建的 APNs 环境。
    /// 应用内切语言的应用调 `PlatformPush.setLocale(_:)`，登记时用它替换 `locale`。
    public static func current() -> PlatformPushDeviceInfo {
        let app = FlareAppInfo.fromBundle(.main)
        return PlatformPushDeviceInfo(
            appBundle: Bundle.main.bundleIdentifier,
            environment: buildEnvironment,
            locale: app.locale,
            timeZone: TimeZone.autoupdatingCurrent.identifier,
            appVersion: app.appVersion
        )
    }

    /// 签名决定的环境在进程内不变，只读一次描述文件。
    private static let buildEnvironment: String = {
        #if targetEnvironment(simulator)
        // 模拟器的令牌只认沙盒，而模拟器构建通常没有描述文件
        return "sandbox"
        #else
        let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
            .flatMap { try? Data(contentsOf: $0) }
        return apnsEnvironment(provisioningProfile: profile)
        #endif
    }()

    /// 描述文件里 `aps-environment` 为 `development` 时是沙盒；其余，包括没有描述文件
    /// （App Store 安装的应用不带它），都是生产。
    static func apnsEnvironment(provisioningProfile: Data?) -> String {
        guard let profile = provisioningProfile,
              let start = profile.range(of: Data("<?xml".utf8)),
              let end = profile.range(of: Data("</plist>".utf8), in: start.lowerBound..<profile.endIndex) else {
            return "production"
        }
        // 描述文件是 CMS 签名包着的一段 plist，取出明文那段解析
        let plist = profile.subdata(in: start.lowerBound..<end.upperBound)
        guard let root = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let entitlements = root["Entitlements"] as? [String: Any] else {
            return "production"
        }
        let value = entitlements["aps-environment"] as? String
            ?? entitlements["com.apple.developer.aps-environment"] as? String
        return value == "development" ? "sandbox" : "production"
    }
}

extension PlatformPushToken {
    /// APNs 令牌的登记：十六进制令牌加上应用信息。
    public static func apns(token: String, device: PlatformPushDeviceInfo) -> PlatformPushToken {
        PlatformPushToken(
            provider: "apns",
            platform: "ios",
            token: token,
            appBundle: device.appBundle,
            environment: device.environment,
            locale: device.locale,
            timeZone: device.timeZone,
            appVersion: device.appVersion,
            capabilities: []
        )
    }

    /// 系统给的设备令牌写成小写十六进制。
    public static func hex(_ deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}
