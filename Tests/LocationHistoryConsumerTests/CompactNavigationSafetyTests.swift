import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

// MARK: - Minimal export helpers

private func exportWith(days jsonDays: String) -> AppExport {
    let json = """
    {
      "schema_version": "1.0",
      "meta": {
        "exported_at": "2024-01-01T00:00:00Z",
        "tool_version": "1.0",
        "source": {}, "output": {}, "config": {}, "filters": {}
      },
      "data": { "days": [\(jsonDays)] }
    }
    """
    return try! AppExportDecoder.decode(data: Data(json.utf8))
}

private func emptyDayExport(_ date: String) -> AppExport {
    exportWith(days: """
    {"date":"\(date)","visits":[],"activities":[],"paths":[]}
    """)
}

private func dayWithVisitExport(_ date: String) -> AppExport {
    exportWith(days: """
    {"date":"\(date)",
     "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T09:00:00Z"}],
     "activities":[],"paths":[]}
    """)
}

private func noDaysExport() -> AppExport {
    exportWith(days: "")
}

private func makeContent(_ export: AppExport) -> AppSessionContent {
    AppSessionContent(export: export, source: .importedFile(filename: "test.json"))
}

// MARK: - Tests

final class CompactNavigationSafetyTests: XCTestCase {

    // MARK: sanitizeSelectionIfContentEmpty

    func testSanitize_clearsSelection_whenSelectedDayHasNoContent() {
        var state = AppSessionState()
        state.show(content: makeContent(emptyDayExport("2024-05-01")))
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.selectedDetail?.hasContent, false)

        state.sanitizeSelectionIfContentEmpty()

        XCTAssertNil(state.selectedDate, "Selection must be cleared when selected day has no content")
        XCTAssertNil(state.selectedDetail)
    }

    func testSanitize_keepsSelection_whenSelectedDayHasContent() {
        var state = AppSessionState()
        state.show(content: makeContent(dayWithVisitExport("2024-05-01")))
        XCTAssertEqual(state.selectedDetail?.hasContent, true)

        state.sanitizeSelectionIfContentEmpty()

        XCTAssertEqual(state.selectedDate, "2024-05-01", "Selection must be preserved when day has content")
    }

    func testSanitize_isNoOp_whenNoSelection() {
        var state = AppSessionState()
        state.sanitizeSelectionIfContentEmpty()
        XCTAssertNil(state.selectedDate)
    }

    func testSanitize_isNoOp_whenNoContentLoaded() {
        var state = AppSessionState()
        XCTAssertNil(state.selectedDate)
        state.sanitizeSelectionIfContentEmpty()
        XCTAssertNil(state.selectedDate)
    }

    // MARK: Restored Days with 0 entries (export has no days at all)

    func testRestoredDays_zeroEntries_selectedDateIsNilFromStart() {
        var state = AppSessionState()
        state.show(content: makeContent(noDaysExport()))

        XCTAssertNil(state.selectedDate, "Export with no days must produce nil selectedDate")
        XCTAssertFalse(state.hasDays)
        // Sanitize must be a safe no-op
        state.sanitizeSelectionIfContentEmpty()
        XCTAssertNil(state.selectedDate)
    }

    // MARK: Restored day with no visits, activities, or paths ("No Content" case)

    func testRestoredEmptyDay_sanitizeRemovesDeadEndSelection() {
        var state = AppSessionState()
        state.show(content: makeContent(emptyDayExport("2024-05-01")))

        // Day is selected (it exists) but has no content — compact dead-end risk
        XCTAssertTrue(state.hasDays, "Day must appear in list")
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.selectedDetail?.hasContent, false,
            "Day with empty visits/activities/paths must report hasContent == false")

        state.sanitizeSelectionIfContentEmpty()

        XCTAssertNil(state.selectedDate, "Compact sanitize must clear selection for empty day")
        XCTAssertEqual(state.presentationState, .importedLoaded, "Session remains in loaded state")
    }

    // MARK: Restored path with no segments (empty paths array → no content)

    func testRestoredDayWithEmptyPathsArray_hasNoContent() {
        // A day with visits=[], activities=[], paths=[] has no content regardless of structure
        let export = emptyDayExport("2024-05-02")
        let detail = makeContent(export).detail(for: "2024-05-02")
        XCTAssertNotNil(detail)
        XCTAssertEqual(detail?.hasContent, false,
            "Day with empty paths array (no segments) must have hasContent == false")
        XCTAssertEqual(detail?.paths.count, 0)
    }

    // MARK: Sanitize after data change

    func testSanitize_clearsAfterReloadWithEmptyDay() {
        var state = AppSessionState()
        // First: load day with content
        state.show(content: makeContent(dayWithVisitExport("2024-05-01")))
        XCTAssertEqual(state.selectedDetail?.hasContent, true)

        // Reload with same date but now empty
        state.show(content: makeContent(emptyDayExport("2024-05-01")))
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.selectedDetail?.hasContent, false)

        state.sanitizeSelectionIfContentEmpty()
        XCTAssertNil(state.selectedDate, "Sanitize after reload must clear empty-day selection")
    }

    // MARK: Compact vs regular — state layer is size-class-agnostic

    func testSanitize_stateLayerIsAgnosticToSizeClass() {
        // sanitizeSelectionIfContentEmpty() always clears empty-day selection.
        // The view layer gates calls to compact only; the state layer itself is unconditional.
        var state = AppSessionState()
        state.show(content: makeContent(emptyDayExport("2024-05-01")))
        XCTAssertEqual(state.selectedDetail?.hasContent, false)

        state.sanitizeSelectionIfContentEmpty()

        XCTAssertNil(state.selectedDate,
            "State-layer sanitize is unconditional; caller (view) decides when to invoke it")
    }
}
