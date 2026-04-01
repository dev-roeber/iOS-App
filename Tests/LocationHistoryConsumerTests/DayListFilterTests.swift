import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class DayListFilterTests: XCTestCase {

    // MARK: - isActive

    func testEmptyFilterIsNotActive() {
        XCTAssertFalse(DayListFilter.empty.isActive)
    }

    func testFilterWithChipIsActive() {
        let filter = DayListFilter(activeChips: [.hasVisits])
        XCTAssertTrue(filter.isActive)
    }

    // MARK: - toggle

    func testToggleAddsChip() {
        var filter = DayListFilter.empty
        filter.toggle(.hasRoutes)
        XCTAssertTrue(filter.activeChips.contains(.hasRoutes))
    }

    func testToggleRemovesChip() {
        var filter = DayListFilter(activeChips: [.hasRoutes])
        filter.toggle(.hasRoutes)
        XCTAssertFalse(filter.activeChips.contains(.hasRoutes))
    }

    func testClearAllResetsChips() {
        var filter = DayListFilter(activeChips: [.hasVisits, .hasRoutes, .favorites])
        filter.clearAll()
        XCTAssertFalse(filter.isActive)
    }

    // MARK: - passes

    func testPassesAlwaysTrueWhenNoChipsActive() {
        let filter = DayListFilter.empty
        let summary = makeSummary(visitCount: 0, pathCount: 0, distanceM: 0)
        XCTAssertTrue(filter.passes(summary: summary, isFavorited: false))
    }

    func testHasVisitsChipFiltersCorrectly() {
        let filter = DayListFilter(activeChips: [.hasVisits])
        let withVisits = makeSummary(visitCount: 2)
        let withoutVisits = makeSummary(visitCount: 0)
        XCTAssertTrue(filter.passes(summary: withVisits, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: withoutVisits, isFavorited: false))
    }

    func testHasRoutesChipFiltersCorrectly() {
        let filter = DayListFilter(activeChips: [.hasRoutes])
        let withRoutes = makeSummary(pathCount: 1)
        let withoutRoutes = makeSummary(pathCount: 0)
        XCTAssertTrue(filter.passes(summary: withRoutes, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: withoutRoutes, isFavorited: false))
    }

    func testHasDistanceChipFiltersCorrectly() {
        let filter = DayListFilter(activeChips: [.hasDistance])
        let withDist = makeSummary(distanceM: 500)
        let withoutDist = makeSummary(distanceM: 0)
        XCTAssertTrue(filter.passes(summary: withDist, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: withoutDist, isFavorited: false))
    }

    func testFavoritesChipFiltersCorrectly() {
        let filter = DayListFilter(activeChips: [.favorites])
        let summary = makeSummary()
        XCTAssertTrue(filter.passes(summary: summary, isFavorited: true))
        XCTAssertFalse(filter.passes(summary: summary, isFavorited: false))
    }

    func testExportableChipFiltersCorrectly() {
        let filter = DayListFilter(activeChips: [.exportable])
        let exportable = makeSummary(visitCount: 1, pathCount: 0)
        let notExportable = makeSummary(visitCount: 0, pathCount: 0)
        XCTAssertTrue(filter.passes(summary: exportable, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: notExportable, isFavorited: false))
    }

    func testAndLogicBetweenMultipleChips() {
        let filter = DayListFilter(activeChips: [.hasVisits, .hasRoutes])
        let both = makeSummary(visitCount: 1, pathCount: 1)
        let onlyVisits = makeSummary(visitCount: 1, pathCount: 0)
        let neither = makeSummary(visitCount: 0, pathCount: 0)
        XCTAssertTrue(filter.passes(summary: both, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: onlyVisits, isFavorited: false))
        XCTAssertFalse(filter.passes(summary: neither, isFavorited: false))
    }

    // MARK: - Helpers

    private func makeSummary(
        visitCount: Int = 0,
        activityCount: Int = 0,
        pathCount: Int = 0,
        distanceM: Double = 0
    ) -> DaySummary {
        DaySummary(
            date: "2024-05-01",
            visitCount: visitCount,
            activityCount: activityCount,
            pathCount: pathCount,
            totalPathPointCount: 0,
            totalPathDistanceM: distanceM,
            hasContent: visitCount > 0 || activityCount > 0 || pathCount > 0,
            exportablePathCount: pathCount
        )
    }
}
