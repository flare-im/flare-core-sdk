import XCTest
@testable import FlarePlatformLifecycle

final class FlareAppInfoTests: XCTestCase {
    private let collected = FlareAppInfo(appVersion: "3.2.1", appBuild: 30201, distribution: nil)

    /// 裸配置：采集到的项写进顶层的 `app` 对象，其余配置原样保留。
    func testFillsABareConfig() {
        let filled = collected.fill(["tenantId": "0"])
        XCTAssertEqual(filled["tenantId"] as? String, "0")
        let app = filled["app"] as? [String: Any]
        XCTAssertEqual(app?["version"] as? String, "3.2.1")
        XCTAssertEqual(app?["build"] as? UInt64, 30201)
        XCTAssertNil(app?["distribution"], "nothing collected, nothing invented")
        XCTAssertNil(filled["appVersion"], "no top-level version fields")
    }

    /// `{ environment, sdkConfig }` 包装：补进 `sdkConfig.app`，宿主显式给的键优先。
    func testFillsTheWrappedConfigAndKeepsExplicitValues() {
        let filled = collected.fill([
            "environment": "production",
            "sdkConfig": ["app": ["version": "3.2.1-hotfix", "distribution": "appstore"]],
        ])
        XCTAssertEqual(filled["environment"] as? String, "production")
        let app = (filled["sdkConfig"] as? [String: Any])?["app"] as? [String: Any]
        XCTAssertEqual(app?["version"] as? String, "3.2.1-hotfix")
        XCTAssertEqual(app?["build"] as? UInt64, 30201)
        XCTAssertEqual(app?["distribution"] as? String, "appstore")
        XCTAssertNil(filled["app"], "a wrapped request is filled inside sdkConfig only")
    }

    /// 宿主只给渠道时，版本与构建号仍由平台包补上。
    func testFillsTheVersionWhenTheHostGivesOnlyTheChannel() {
        let filled = collected.fill(["app": ["channel": "stable"]])
        let app = filled["app"] as? [String: Any]
        XCTAssertEqual(app?["channel"] as? String, "stable")
        XCTAssertEqual(app?["version"] as? String, "3.2.1")
        XCTAssertEqual(app?["build"] as? UInt64, 30201)
    }

    /// 语言和桌面目标同样逐键补，宿主给了就不动。
    func testFillsTheLocaleAndTargetByKey() {
        let info = FlareAppInfo(locale: "zh-Hant-TW", target: "darwin-aarch64")
        let filled = info.fill(["app": ["locale": "en"]])
        let app = filled["app"] as? [String: Any]
        XCTAssertEqual(app?["locale"] as? String, "en")
        XCTAssertEqual(app?["target"] as? String, "darwin-aarch64")
    }

    /// 空串等于没给。
    func testABlankHostValueIsFilled() {
        let filled = collected.fill(["app": ["version": "  "]])
        XCTAssertEqual((filled["app"] as? [String: Any])?["version"] as? String, "3.2.1")
    }

    /// 什么都没采集到时不写 `app`：引擎拿到 `app` 会整体替换构建期的值。
    func testWritesNoAppWhenNothingIsKnown() {
        let filled = FlareAppInfo().fill(["tenantId": "0"])
        XCTAssertNil(filled["app"])
    }

    /// 构建号只认纯数字：`1.2.3` 这类写法换算不出可比较的整数，不猜。
    func testBuildNumberMustBeAnInteger() {
        XCTAssertEqual(FlareAppInfo.parseBuildNumber("42"), 42)
        XCTAssertEqual(FlareAppInfo.parseBuildNumber(" 1007 "), 1007)
        XCTAssertNil(FlareAppInfo.parseBuildNumber("1.2.3"))
        XCTAssertNil(FlareAppInfo.parseBuildNumber(""))
    }

    /// TestFlight 带沙盒收据，App Store 带正式收据；收据文件不存在（Xcode 安装）时不判断。
    func testDistributionComesFromTheReceipt() {
        let sandbox = URL(fileURLWithPath: "/app/StoreKit/sandboxReceipt")
        let store = URL(fileURLWithPath: "/app/StoreKit/receipt")
        XCTAssertEqual(FlareAppInfo.distribution(receiptURL: sandbox, fileExists: { _ in true }), "testflight")
        XCTAssertEqual(FlareAppInfo.distribution(receiptURL: store, fileExists: { _ in true }), "appstore")
        XCTAssertNil(FlareAppInfo.distribution(receiptURL: sandbox, fileExists: { _ in false }))
        XCTAssertNil(FlareAppInfo.distribution(receiptURL: nil))
    }
}
