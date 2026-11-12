import Foundation
import XCTest
@testable import FlareCoreAppleSDK

final class FfiJSONFragmentTests: XCTestCase {
    func testEncodedScanURLPreservesEscapesAndUnicodeWithoutOuterJSONQuotes() throws {
        let expected = "https://scan.flare.test/p/demo/opaque?label=\"扫一扫\"\nnext"
        let encoded = try JSONSerialization.data(withJSONObject: expected, options: [.fragmentsAllowed])
        XCTAssertEqual(FfiJson.decode(String(decoding: encoded, as: UTF8.self)) as? String, expected)
    }

    func testBooleansRemainBooleans() {
        XCTAssertEqual(FfiJson.decode(" \ntrue\t") as? Bool, true)
        XCTAssertEqual(FfiJson.decode("false") as? Bool, false)
    }

    func testIntegerAboveDoublePrecisionRemainsExact() {
        XCTAssertEqual((FfiJson.decode("9007199254740993") as? NSNumber)?.int64Value, 9_007_199_254_740_993)
    }

    func testJSONNullIsDistinctFromEmptyUnitResult() {
        XCTAssertTrue(FfiJson.decode("null") is NSNull)
        XCTAssertNil(FfiJson.decode(""))
    }

    func testEncodedEmptyStringIsAValidValue() {
        XCTAssertEqual(FfiJson.decode("\"\"") as? String, "")
    }

    func testObjectAndArrayResponsesKeepTheirExistingShape() {
        let object = FfiJson.decode("{\"enabled\":true,\"count\":2}") as? [String: Any]
        XCTAssertEqual(object?["enabled"] as? Bool, true)
        XCTAssertEqual(object?["count"] as? Int, 2)
        let array = FfiJson.decode("[\"a\",\"b\"]") as? [String]
        XCTAssertEqual(array, ["a", "b"])
    }

    func testMalformedOrUnencodedPayloadIsNotTreatedAsAString() {
        XCTAssertNil(FfiJson.decode("{"))
        XCTAssertNil(FfiJson.decode("true trailing"))
        XCTAssertNil(FfiJson.decode("https://scan.flare.test/p/demo/opaque"))
    }
}

