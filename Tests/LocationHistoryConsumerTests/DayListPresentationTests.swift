import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class DayListPresentationTests: XCTestCase {
    func testExportSelectionCopyDistinguishesEmptyAndPopulatedSelection() {
        XCTAssertEqual(
            DayListPresentation.exportSelectionTitle(count: 0),
            "No export days selected"
        )
        XCTAssertEqual(
            DayListPresentation.exportSelectionMessage(count: 0),
            "Mark days in Export and they will stay highlighted here."
        )
        XCTAssertEqual(
            DayListPresentation.exportSelectionTitle(count: 2),
            "2 days selected for export"
        )
        XCTAssertEqual(
            DayListPresentation.exportSelectionMessage(count: 2),
            "The day list mirrors the current GPX selection so marked days stay easy to spot."
        )
    }

    func testSearchEmptyMessageMentionsExportSelectionWhenRelevant() {
        XCTAssertEqual(
            DayListPresentation.searchEmptyMessage(query: "2024-05", exportSelectionCount: 0),
            "No days match \"2024-05\". Try a broader date fragment."
        )
        XCTAssertEqual(
            DayListPresentation.searchEmptyMessage(query: "2024-05", exportSelectionCount: 1),
            "No days match \"2024-05\". 1 selected export day remains marked when you clear the search."
        )
    }

    func testFilteredSummariesTreatsBlankQueryAsInactiveAndMatchesDateFragments() {
        let summaries = makeSummaries(daysJSON: """
        [
          {"date":"2024-05-01","visits":[],"activities":[],"paths":[]},
          {"date":"2024-06-02","visits":[],"activities":[],"paths":[]}
        ]
        """)

        XCTAssertEqual(
            DayListPresentation.filteredSummaries(summaries, query: " ").map(\.date),
            ["2024-05-01", "2024-06-02"]
        )
        XCTAssertEqual(
            DayListPresentation.filteredSummaries(summaries, query: "2024-05").map(\.date),
            ["2024-05-01"]
        )
    }

    func testReselectTargetPrefersTodayThenMostRecentPastContentfulDay() {
        let summaries = makeSummaries(daysJSON: """
        [
          {"date":"2024-05-01","visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],"activities":[],"paths":[]},
          {"date":"2024-05-02","visits":[],"activities":[],"paths":[]},
          {"date":"2024-05-03","visits":[{"lat":48.1,"lon":11.1,"start_time":"2024-05-03T08:00:00Z","end_time":"2024-05-03T08:30:00Z"}],"activities":[],"paths":[]}
        ]
        """)

        XCTAssertEqual(
            DayListPresentation.reselectTargetDate(summaries, relativeTo: makeReferenceDate("2024-05-03")),
            "2024-05-03"
        )
        XCTAssertEqual(
            DayListPresentation.reselectTargetDate(summaries, relativeTo: makeReferenceDate("2024-05-02")),
            "2024-05-01"
        )
        XCTAssertEqual(
            DayListPresentation.reselectTargetDate(summaries, relativeTo: makeReferenceDate("2024-04-30")),
            "2024-05-01"
        )
    }

    func testReselectTargetReturnsNilWhenNoContentfulDaysExist() {
        let summaries = makeSummaries(daysJSON: """
        [
          {"date":"2024-05-01","visits":[],"activities":[],"paths":[]},
          {"date":"2024-05-02","visits":[],"activities":[],"paths":[]}
        ]
        """)

        XCTAssertNil(
            DayListPresentation.reselectTargetDate(summaries, relativeTo: makeReferenceDate("2024-05-02"))
        )
    }

    private func makeSummaries(daysJSON: String) -> [DaySummary] {
        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "tool_version": "test",
            "exported_at": "2026-03-19T00:00:00Z",
            "source": {
              "zip_basename": "test.zip",
              "input_format": "records"
            },
            "output": {},
            "config": {
              "mode": "paths",
              "split_mode": "single"
            },
            "filters": {}
          },
          "data": {
            "days": \(daysJSON)
          },
          "stats": {
            "activities": {},
            "periods": []
          }
        }
        """

        let data = Data(json.utf8)
        let export = try! AppExportDecoder.decode(data: data)
        return AppExportQueries.daySummaries(from: export)
    }

    private func makeReferenceDate(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: isoDate)!
    }
}
