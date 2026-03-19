import XCTest
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
}
