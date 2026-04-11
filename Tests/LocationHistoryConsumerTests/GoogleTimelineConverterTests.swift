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

    func testPreservesZuluTimestampAndKeepsUTCDayStableAcrossHostTimeZones() throws {
        let result = try withDefaultTimeZone("Pacific/Auckland") {
            try convertTimeline(
                entries: [
                    visitEntry(
                        startTime: "2024-01-15T12:34:56Z",
                        endTime: "2024-01-15T13:00:00Z"
                    )
                ]
            )
        }

        XCTAssertEqual(result.data.days.map(\.date), ["2024-01-15"])
        XCTAssertEqual(result.data.days.first?.visits.first?.startTime, "2024-01-15T12:34:56Z")
        XCTAssertEqual(result.data.days.first?.visits.first?.endTime, "2024-01-15T13:00:00Z")
    }

    func testGroupsExplicitPlusOneOffsetByAbsoluteUTCDay() throws {
        let result = try withDefaultTimeZone("America/Los_Angeles") {
            try convertTimeline(
                entries: [
                    visitEntry(
                        startTime: "2024-03-20T00:30:00+01:00",
                        endTime: "2024-03-20T01:00:00+01:00"
                    )
                ]
            )
        }

        XCTAssertEqual(result.data.days.map(\.date), ["2024-03-19"])
        XCTAssertEqual(result.data.days.first?.visits.first?.startTime, "2024-03-20T00:30:00+01:00")
    }

    func testGroupsExplicitPlusTwoOffsetByAbsoluteUTCDay() throws {
        let result = try withDefaultTimeZone("America/Los_Angeles") {
            try convertTimeline(
                entries: [
                    visitEntry(
                        startTime: "2024-03-20T02:30:00+02:00",
                        endTime: "2024-03-20T03:00:00+02:00"
                    )
                ]
            )
        }

        XCTAssertEqual(result.data.days.map(\.date), ["2024-03-20"])
        XCTAssertEqual(result.data.days.first?.visits.first?.startTime, "2024-03-20T02:30:00+02:00")
    }

    func testTimelinePathOffsetsRemainCorrectAcrossDSTForwardTransition() throws {
        let result = try withDefaultTimeZone("Europe/Berlin") {
            try convertTimeline(
                entries: [
                    pathEntry(
                        startTime: "2024-03-31T01:30:00+01:00",
                        endTime: "2024-03-31T03:30:00+02:00",
                        offsets: ["0", "60"]
                    )
                ]
            )
        }

        let points = try XCTUnwrap(result.data.days.first?.paths.first?.points)
        XCTAssertEqual(result.data.days.map(\.date), ["2024-03-31"])
        XCTAssertEqual(points.map(\.time), ["2024-03-31T00:30:00Z", "2024-03-31T01:30:00Z"])
    }

    func testTimelinePathOffsetsRemainCorrectAcrossDSTBackwardTransition() throws {
        let result = try withDefaultTimeZone("Europe/Berlin") {
            try convertTimeline(
                entries: [
                    pathEntry(
                        startTime: "2024-10-27T02:30:00+02:00",
                        endTime: "2024-10-27T02:30:00+01:00",
                        offsets: ["0", "60"]
                    )
                ]
            )
        }

        let points = try XCTUnwrap(result.data.days.first?.paths.first?.points)
        XCTAssertEqual(result.data.days.map(\.date), ["2024-10-27"])
        XCTAssertEqual(points.map(\.time), ["2024-10-27T00:30:00Z", "2024-10-27T01:30:00Z"])
    }

    func testGroupsLocalMidnightBoundaryEntriesIntoSingleUTCDayAndLeavesInsightsStable() throws {
        let result = try withDefaultTimeZone("Europe/Berlin") {
            try convertTimeline(
                entries: [
                    visitEntry(
                        startTime: "2024-03-20T23:55:00+01:00",
                        endTime: "2024-03-21T00:00:00+01:00"
                    ),
                    visitEntry(
                        startTime: "2024-03-21T00:05:00+01:00",
                        endTime: "2024-03-21T00:10:00+01:00"
                    )
                ]
            )
        }

        let summaries = AppExportQueries.daySummaries(from: result)
        let insights = AppExportQueries.insights(from: result)

        XCTAssertEqual(result.data.days.map(\.date), ["2024-03-20"])
        XCTAssertEqual(summaries.map(\.date), ["2024-03-20"])
        XCTAssertEqual(summaries.first?.visitCount, 2)
        XCTAssertEqual(insights.dateRange?.firstDate, "2024-03-20")
        XCTAssertEqual(insights.dateRange?.lastDate, "2024-03-20")
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

    private func withDefaultTimeZone<T>(_ identifier: String, perform: () throws -> T) throws -> T {
        let originalTimeZone = NSTimeZone.default
        defer { NSTimeZone.default = originalTimeZone }
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: identifier))
        return try perform()
    }

    private func convertTimeline(entries: [String]) throws -> AppExport {
        let json = """
        [
        \(entries.joined(separator: ",\n"))
        ]
        """
        return try GoogleTimelineConverter.convert(data: Data(json.utf8))
    }

    private func visitEntry(startTime: String, endTime: String) -> String {
        """
        {
            "startTime": "\(startTime)",
            "endTime": "\(endTime)",
            "visit": {
                "topCandidate": {
                    "placeLocation": "geo:52.52,13.40",
                    "semanticType": "HOME"
                }
            }
        }
        """
    }

    private func pathEntry(startTime: String, endTime: String, offsets: [String]) -> String {
        let points = offsets.enumerated().map { index, offset in
            """
            {
                "durationMinutesOffsetFromStartTime": "\(offset)",
                "point": "geo:52.5\(index),13.4\(index)"
            }
            """
        }.joined(separator: ",\n")

        return """
        {
            "startTime": "\(startTime)",
            "endTime": "\(endTime)",
            "timelinePath": [
                \(points)
            ]
        }
        """
    }
}
