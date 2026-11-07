import Foundation

/// 宿主应用的版本信息：随 `sdk.init` 的 `app` 对象交给引擎，引擎在 CONNECT 时上报
/// （`app.version` / `app.build` / `app.distribution`），服务端据此做版本兼容判断与排查。
///
/// 默认从 `Bundle.main` 自动采集；宿主在 init 配置的 `app` 对象里显式给的 `version` / `build` /
/// `distribution` 一律优先，这里只补缺的键。不依赖引擎，社交 SDK 等其它 SDK 可以同样使用。
public struct FlareAppInfo: Sendable, Equatable {
    /// 版本名，对应 `CFBundleShortVersionString`。
    public var appVersion: String?
    /// 单调递增的整数构建号，对应 `CFBundleVersion`；服务端版本比较只用它。
    public var appBuild: UInt64?
    /// 分发渠道：按收据判断 `testflight` / `appstore`；没有收据（Xcode 安装、企业分发）不填，由宿主给。
    public var distribution: String?
    /// 系统首选语言（BCP-47）：更新说明按它选。App 内切语言的宿主显式传 `app.locale`。
    public var locale: String?
    /// 桌面目标（`darwin-aarch64` 等），发布清单按它选制品；iOS 没有。
    public var target: String?

    public init(
        appVersion: String? = nil,
        appBuild: UInt64? = nil,
        distribution: String? = nil,
        locale: String? = nil,
        target: String? = nil
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.distribution = distribution
        self.locale = locale
        self.target = target
    }

    /// 从 bundle 的 Info.plist 读版本名与构建号，从 App Store 收据判断分发渠道。
    ///
    /// `CFBundleVersion` 只有是纯数字时才当构建号：服务端按整数比较，`1.2.3` 这类写法换算不出
    /// 单调整数，不猜，留空由宿主经 `app.build` 传入。
    public static func fromBundle(_ bundle: Bundle = .main) -> FlareAppInfo {
        let info = bundle.infoDictionary ?? [:]
        return FlareAppInfo(
            appVersion: nonBlank(info["CFBundleShortVersionString"] as? String),
            appBuild: (info["CFBundleVersion"] as? String).flatMap(parseBuildNumber),
            distribution: distribution(receiptURL: bundle.appStoreReceiptURL),
            locale: nonBlank(Locale.preferredLanguages.first),
            target: desktopTarget
        )
    }

    private static var desktopTarget: String? {
        #if os(macOS) && arch(arm64)
        return "darwin-aarch64"
        #elseif os(macOS)
        return "darwin-x86_64"
        #else
        return nil
        #endif
    }

    static func parseBuildNumber(_ raw: String) -> UInt64? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        return UInt64(trimmed)
    }

    /// TestFlight 安装带沙盒收据（`sandboxReceipt`），App Store 安装带正式收据（`receipt`）。
    /// 收据路径总能取到，文件存在才算数：Xcode 直接安装的构建路径同样指向 `sandboxReceipt`，但没有文件。
    static func distribution(
        receiptURL: URL?,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> String? {
        guard let receiptURL, fileExists(receiptURL.path) else {
            return nil
        }
        switch receiptURL.lastPathComponent {
        case "sandboxReceipt":
            return "testflight"
        case "receipt":
            return "appstore"
        default:
            return nil
        }
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }
        return value
    }

    /// 把还没填的项补进 init 配置的 `app` 对象（`{ version, build, distribution, channel }`）。
    /// 引擎接受两种形状（与 `flare_sdk_init` 的解析一致）：裸配置补进顶层的 `app`；
    /// 带 `environment` / `sdkConfig` 的包装补进 `sdkConfig.app`。宿主给了的键原样保留（空串算没给），
    /// 只补缺的键；`channel` 不自动采集。什么都没有可补时不写 `app`：引擎拿到 `app` 会整体替换构建期的值。
    public func fill(_ request: [String: Any]) -> [String: Any] {
        var root = request
        let wrapped = root["sdkConfig"] != nil || root["environment"] != nil
        var config = wrapped ? (root["sdkConfig"] as? [String: Any] ?? [:]) : root
        var app = config["app"] as? [String: Any] ?? [:]
        func setIfMissing(_ key: String, _ value: Any?) {
            guard let value else { return }
            if let existing = app[key], !(existing is NSNull) {
                if let text = existing as? String, text.trimmingCharacters(in: .whitespaces).isEmpty {
                    app[key] = value
                }
                return
            }
            app[key] = value
        }
        setIfMissing("version", appVersion)
        setIfMissing("build", appBuild)
        setIfMissing("distribution", distribution)
        setIfMissing("locale", locale)
        setIfMissing("target", target)
        if !app.isEmpty {
            config["app"] = app
        }
        if wrapped {
            root["sdkConfig"] = config
            return root
        }
        return config
    }
}
