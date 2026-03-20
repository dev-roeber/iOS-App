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

    func testHandlesEmptyArray() throws {
        let data = "[]".data(using: .utf8)!
        do {
            _ = try GoogleTimelineConverter.convert(data: data)
            XCTFail("Should throw notGoogleTimeline for empty array")
        } catch let error as GoogleTimelineConverter.ConversionError {
            XCTAssertEqual(error, .notGoogleTimeline)
        } catch {
            XCTFail("Expected ConversionError.notGoogleTimeline but got: \(error)")
        }
    }

    func testSkipsEntriesWithMissingFields() throws {
        // Entries missing visit/activity/path are filtered out.
        // If an entry has a valid startTime but no content, it's skipped during buildExportDict.
        // If NO entry has a parseable startTime, it throws notGoogleTimeline.
        let json = """
        [
            { "startTime": "invalid-date" },
            { "someOtherField": "data" }
        ]
        """
        let data = json.data(using: .utf8)!
        do {
            _ = try GoogleTimelineConverter.convert(data: data)
            XCTFail("Should throw if no valid entries with startTime were found")
        } catch let error as GoogleTimelineConverter.ConversionError {
            XCTAssertEqual(error, .notGoogleTimeline)
        } catch {
            XCTFail("Expected ConversionError.notGoogleTimeline but got: \(error)")
        }
    }

    func testDetectsValidGoogleTimelineFormat() {
        let validJSON = "[{\"startTime\": \"2024-01-01T00:00:00Z\"}]".data(using: .utf8)!
        XCTAssertTrue(GoogleTimelineConverter.isGoogleTimeline(validJSON))

        let invalidJSON = "{\"foo\": \"bar\"}".data(using: .utf8)!
        XCTAssertFalse(GoogleTimelineConverter.isGoogleTimeline(invalidJSON))
    }
}
