import XCTest
@testable import LocationHistoryConsumerAppSupport

final class InsightsDrilldownTests: XCTestCase {

    // MARK: - InsightsDrilldownAction equality

    func testFilterDaysToDateEquality() {
        let a = InsightsDrilldownAction.filterDaysToDate("2024-05-01")
        let b = InsightsDrilldownAction.filterDaysToDate("2024-05-01")
        XCTAssertEqual(a, b)
    }

    func testFilterDaysToDateRangeEquality() {
        let a = InsightsDrilldownAction.filterDaysToDateRange(fromDate: "2024-05-01", toDate: "2024-05-31")
        let b = InsightsDrilldownAction.filterDaysToDateRange(fromDate: "2024-05-01", toDate: "2024-05-31")
        XCTAssertEqual(a, b)
    }

    func testPrefillExportForDateEquality() {
        let a = InsightsDrilldownAction.prefillExportForDate("2024-06-01")
        let b = InsightsDrilldownAction.prefillExportForDate("2024-06-01")
        XCTAssertEqual(a, b)
    }

    func testDifferentActionsAreNotEqual() {
        let a = InsightsDrilldownAction.filterDaysToDate("2024-05-01")
        let b = InsightsDrilldownAction.prefillExportForDate("2024-05-01")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - InsightsDrilldownTarget factories

    func testShowDayTargetHasCorrectAction() {
        let target = InsightsDrilldownTarget.showDay("2024-05-01")
        XCTAssertEqual(target.action, .filterDaysToDate("2024-05-01"))
        XCTAssertFalse(target.label.isEmpty)
    }

    func testExportDayTargetHasCorrectAction() {
        let target = InsightsDrilldownTarget.exportDay("2024-05-01")
        XCTAssertEqual(target.action, .prefillExportForDate("2024-05-01"))
        XCTAssertFalse(target.label.isEmpty)
    }

    func testShowFavoritesTargetFiltersToFavorites() {
        let target = InsightsDrilldownTarget.showFavorites
        if case .filterDays(let filter) = target.action {
            XCTAssertTrue(filter.activeChips.contains(.favorites))
        } else {
            XCTFail("Expected filterDays action")
        }
    }

    func testShowDaysWithRoutesTargetFiltersToRoutes() {
        let target = InsightsDrilldownTarget.showDaysWithRoutes
        if case .filterDays(let filter) = target.action {
            XCTAssertTrue(filter.activeChips.contains(.hasRoutes))
        } else {
            XCTFail("Expected filterDays action")
        }
    }

    // MARK: - No drilldown for purely aggregated values

    func testFilterDaysWithEmptyFilterIsNotAConcreteAction() {
        // A DayListFilter with no chips is not meaningful as a drilldown destination.
        // Verify that empty filter isActive is false — callers should guard against this.
        let action = InsightsDrilldownAction.filterDays(.empty)
        if case .filterDays(let filter) = action {
            XCTAssertFalse(filter.isActive, "Empty filter drilldown should not be used for UI targets")
        }
    }

    // MARK: - UUID identity

    func testTargetIdsAreUnique() {
        let a = InsightsDrilldownTarget.showDay("2024-05-01")
        let b = InsightsDrilldownTarget.showDay("2024-05-01")
        XCTAssertNotEqual(a.id, b.id)
    }
}
