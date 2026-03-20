import XCTest
@testable import LocationHistoryConsumerAppSupport
import LocationHistoryConsumer

final class GoogleTimelineConverterTests: XCTestCase {

    func testGroupEntriesByUTCDay() throws {
        // Given an entry at 23:50 UTC (2024-03-20)
        let json = """
        [
            {
                "startTime": "2024-03-20T23:50:00.000Z",
                "endTime": "2024-03-20T23:55:00.000Z",
                "visit": {
                    "topCandidate": {
                        "placeLocation": "geo:52.52,13.40",
                        "semanticType": "HOME"
                    }
                }
            }
        ]
        """
        let data = json.data(using: .utf8)!

        // Save current timezone and force a different one (e.g. UTC+1)
        let originalTimeZone = NSTimeZone.default
        defer { NSTimeZone.default = originalTimeZone }

        // When system is in UTC+1, 23:50 UTC is 00:50 on the *next* day (2024-03-21)
        NSTimeZone.default = TimeZone(secondsFromGMT: 3600)!

        // When we convert
        let result = try GoogleTimelineConverter.convert(data: data)

        // Then it SHOULD still be grouped under 2024-03-20 because we want UTC grouping
        XCTAssertEqual(result.data.days.count, 1)
        XCTAssertEqual(result.data.days.first?.date, "2024-03-20")
    }
}
