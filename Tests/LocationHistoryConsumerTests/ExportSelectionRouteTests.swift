import XCTest
@testable import LocationHistoryConsumerAppSupport

final class ExportSelectionRouteTests: XCTestCase {

    // MARK: - toggleRoute

    func testToggleRouteAddsIndex() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        XCTAssertTrue(state.isRouteSelected(day: "2024-05-01", routeIndex: 0))
    }

    func testToggleRouteRemovesIndex() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        // After removing from an explicit set, index is still in the set (empty set != nil set)
        // The set exists but is empty; explicitly not selected
        XCTAssertFalse(state.isRouteSelected(day: "2024-05-01", routeIndex: 0))
    }

    func testToggleRouteFromImplicitAllRemovesTappedRouteFromExplicitSubset() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 1, availableRouteIndices: [0, 1, 2])

        XCTAssertEqual(state.effectiveRouteIndices(day: "2024-05-01", allCount: 3), IndexSet([0, 2]))
        XCTAssertTrue(state.hasExplicitRouteSelection)
    }

    func testToggleRouteReturnsToImplicitAllWhenSubsetMatchesAllRoutesAgain() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 1, availableRouteIndices: [0, 1, 2])
        state.toggleRoute(day: "2024-05-01", routeIndex: 1, availableRouteIndices: [0, 1, 2])

        XCTAssertEqual(state.effectiveRouteIndices(day: "2024-05-01", allCount: 3), IndexSet([0, 1, 2]))
        XCTAssertFalse(state.hasExplicitRouteSelection)
    }

    func testIsRouteSelectedReturnsTrueByDefaultWhenNoExplicitSelection() {
        let state = ExportSelectionState()
        XCTAssertTrue(state.isRouteSelected(day: "2024-05-01", routeIndex: 0))
        XCTAssertTrue(state.isRouteSelected(day: "2024-05-01", routeIndex: 99))
    }

    // MARK: - effectiveRouteIndices

    func testEffectiveIndicesReturnsAllWhenNoExplicitSelection() {
        let state = ExportSelectionState()
        let indices = state.effectiveRouteIndices(day: "2024-05-01", allCount: 3)
        XCTAssertEqual(indices, IndexSet([0, 1, 2]))
    }

    func testEffectiveIndicesReturnsOnlyExplicitlySelected() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        state.toggleRoute(day: "2024-05-01", routeIndex: 2)
        let indices = state.effectiveRouteIndices(day: "2024-05-01", allCount: 3)
        XCTAssertEqual(indices, IndexSet([0, 2]))
    }

    func testEffectiveIndicesReturnsEmptyWhenAllExplicitlyDeselected() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        state.toggleRoute(day: "2024-05-01", routeIndex: 0) // deselect
        let indices = state.effectiveRouteIndices(day: "2024-05-01", allCount: 1)
        XCTAssertTrue(indices.isEmpty)
    }

    // MARK: - clearRouteSelection

    func testClearRouteSelectionResetsToAllRoutes() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 1)
        state.clearRouteSelection(day: "2024-05-01")
        // After clear, nil-based default (all selected) restored
        XCTAssertTrue(state.isRouteSelected(day: "2024-05-01", routeIndex: 0))
        XCTAssertTrue(state.isRouteSelected(day: "2024-05-01", routeIndex: 1))
        XCTAssertFalse(state.hasExplicitRouteSelection)
    }

    // MARK: - hasExplicitRouteSelection

    func testHasExplicitRouteSelectionFalseInitially() {
        XCTAssertFalse(ExportSelectionState().hasExplicitRouteSelection)
    }

    func testHasExplicitRouteSelectionTrueAfterToggle() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        XCTAssertTrue(state.hasExplicitRouteSelection)
    }

    // MARK: - clearAll clears route selections

    func testClearAllRemovesRouteSelections() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        state.toggle("2024-05-01")
        state.clearAll()
        XCTAssertFalse(state.hasExplicitRouteSelection)
        XCTAssertTrue(state.isEmpty)
    }

    // MARK: - Export Summary

    func testExplicitRouteSelectionCountReflectsActiveDays() {
        var state = ExportSelectionState()
        state.toggleRoute(day: "2024-05-01", routeIndex: 0)
        state.toggleRoute(day: "2024-05-02", routeIndex: 1)
        XCTAssertEqual(state.explicitRouteSelectionCount, 2)
    }
}
