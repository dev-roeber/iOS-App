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
}
