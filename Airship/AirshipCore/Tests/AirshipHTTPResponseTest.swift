/* Copyright Airship and Contributors */

import XCTest

@testable
public import AirshipCore

public extension AirshipHTTPResponse {

    static func make(result: T?, statusCode: Int, headers: [String: String]) -> AirshipHTTPResponse<T> {
        return .init(result: result, statusCode: statusCode, headers: headers)
    }
}

final class AirshipHTTPResponseRetryAfterTest: XCTestCase {

    // 2023-07-10T18:10:46Z
    private let now = Date(timeIntervalSince1970: 1689012646)

    private func response(retryAfter: String?) -> AirshipHTTPResponse<Void> {
        var headers: [String: String] = [:]
        if let retryAfter { headers["Retry-After"] = retryAfter }
        return AirshipHTTPResponse(result: nil, statusCode: 429, headers: headers)
    }

    // MARK: - Absence

    func testNilWhenHeaderAbsent() {
        XCTAssertNil(response(retryAfter: nil).retryAfter(now: now))
    }

    func testNilWhenHeaderEmpty() {
        XCTAssertNil(response(retryAfter: "").retryAfter(now: now))
    }

    func testNilWhenHeaderWhitespace() {
        XCTAssertNil(response(retryAfter: "   ").retryAfter(now: now))
    }

    // MARK: - delay-seconds

    func testNumericSeconds() {
        XCTAssertEqual(120, response(retryAfter: "120").retryAfter(now: now))
    }

    func testFractionalSeconds() {
        XCTAssertEqual(1.5, response(retryAfter: "1.5").retryAfter(now: now))
    }

    func testZeroSeconds() {
        XCTAssertEqual(0, response(retryAfter: "0").retryAfter(now: now))
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(120, response(retryAfter: "  120  ").retryAfter(now: now))
    }

    func testRejectsNegativeNumber() {
        // RFC 7231 §7.1.3 delay-seconds grammar excludes signed values.
        XCTAssertNil(response(retryAfter: "-5").retryAfter(now: now))
    }

    func testRejectsScientificNotation() {
        // Double parses "1e6", but it's outside the delay-seconds grammar.
        XCTAssertNil(response(retryAfter: "1e6").retryAfter(now: now))
    }

    func testRejectsLeadingPlus() {
        XCTAssertNil(response(retryAfter: "+5").retryAfter(now: now))
    }

    func testRejectsTrailingGarbage() {
        XCTAssertNil(response(retryAfter: "120s").retryAfter(now: now))
    }

    // MARK: - HTTP-date (RFC 7231 §7.1.1.1)

    func testHttpDateImfFixdate() {
        // 60 seconds after `now`.
        let value = "Mon, 10 Jul 2023 18:11:46 GMT"
        XCTAssertEqual(60, response(retryAfter: value).retryAfter(now: now))
    }

    func testHttpDateRfc850() {
        let value = "Monday, 10-Jul-23 18:11:46 GMT"
        XCTAssertEqual(60, response(retryAfter: value).retryAfter(now: now))
    }

    func testHttpDateAsctime() {
        let value = "Mon Jul 10 18:11:46 2023"
        XCTAssertEqual(60, response(retryAfter: value).retryAfter(now: now))
    }

    func testHttpDateInPastClampedToZero() {
        let value = "Mon, 10 Jul 2023 18:09:46 GMT"  // 60s before now
        XCTAssertEqual(0, response(retryAfter: value).retryAfter(now: now))
    }

    // MARK: - ISO 8601 fallback

    func testIso8601Date() {
        let value = "2023-07-10T18:11:46Z"  // 60s after now
        XCTAssertEqual(60, response(retryAfter: value).retryAfter(now: now))
    }

    func testIso8601DateInPastClampedToZero() {
        let value = "2023-07-10T18:09:46Z"  // 60s before now
        XCTAssertEqual(0, response(retryAfter: value).retryAfter(now: now))
    }

    func testIso8601ReturnsDeltaNotAbsoluteEpoch() {
        // Regression: previously returned `timeIntervalSince1970` (~1.7B seconds)
        // instead of the delta from now.
        let value = "2023-07-10T18:11:46Z"
        let result = response(retryAfter: value).retryAfter(now: now)
        XCTAssertNotNil(result)
        XCTAssertLessThan(result!, 3600, "Should be a delta (~60s), not an absolute epoch")
    }

    // MARK: - Garbage

    func testGarbageReturnsNil() {
        XCTAssertNil(response(retryAfter: "what").retryAfter(now: now))
    }

    // MARK: - Case-insensitive header lookup

    func testHeaderLookupIsCaseInsensitive() {
        // RFC 7230: header field names are case-insensitive.
        let lower = AirshipHTTPResponse<Void>(result: nil, statusCode: 429, headers: ["retry-after": "120"])
        XCTAssertEqual(120, lower.retryAfter(now: now))

        let upper = AirshipHTTPResponse<Void>(result: nil, statusCode: 429, headers: ["RETRY-AFTER": "60"])
        XCTAssertEqual(60, upper.retryAfter(now: now))
    }

    func testLocationHeaderLookupIsCaseInsensitive() {
        let response = AirshipHTTPResponse<Void>(
            result: nil,
            statusCode: 307,
            headers: ["location": "https://example.com/redirect"]
        )
        XCTAssertEqual(URL(string: "https://example.com/redirect"), response.locationHeader)
    }
}
