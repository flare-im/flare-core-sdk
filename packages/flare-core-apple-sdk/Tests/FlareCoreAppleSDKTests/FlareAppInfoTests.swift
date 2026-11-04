import XCTest
@testable import FlareCoreAppleSDK

final class FlareAppInfoTests: XCTestCase {
    private let collected = FlareAppInfo(appVersion: "3.2.1", appBuild: 30201, distribution: nil)

    /// 裸配置：缺的项补在顶层，已有的配置原样保留。
    func testFillsABareConfig() {
        let filled = collected.fill(["wsUrl": "wss://im.example.com/ws"])
        XCTAssertEqual(filled["wsUrl"] as? String, "wss://im.example.com/ws")
        XCTAssertEqual(filled["appVersion"] as? String, "3.2.1")
        XCTAssertEqual(filled["appBuild"] as? UInt64, 30201)
        XCTAssertNil(filled["distribution"], "nothing collected, nothing invented")
    }

    /// `{ environment, sdkConfig }` 包装：补进 `sdkConfig`，宿主显式给的值优先。
    func testFillsTheWrappedConfigAndKeepsExplicitValues() {
        let filled = collected.fill([
            "environment": "production",
            "sdkConfig": ["appVersion": "3.2.1-hotfix", "distribution": "appstore"],
        ])
        XCTAssertEqual(filled["environment"] as? String, "production")
        let config = filled["sdkConfig"] as? [String: Any]
        XCTAssertEqual(config?["appVersion"] as? String, "3.2.1-hotfix")
        XCTAssertEqual(config?["appBuild"] as? UInt64, 30201)
        XCTAssertEqual(config?["distribution"] as? String, "appstore")
        XCTAssertNil(filled["appVersion"], "a wrapped request is filled inside sdkConfig only")
    }

    /// 构建号只认纯数字：`1.2.3` 这类写法换算不出可比较的整数，不猜。
    func testBuildNumberMustBeAnInteger() {
        XCTAssertEqual(FlareAppInfo.parseBuildNumber("42"), 42)
        XCTAssertEqual(FlareAppInfo.parseBuildNumber(" 1007 "), 1007)
        XCTAssertNil(FlareAppInfo.parseBuildNumber("1.2.3"))
        XCTAssertNil(FlareAppInfo.parseBuildNumber(""))
    }
}
