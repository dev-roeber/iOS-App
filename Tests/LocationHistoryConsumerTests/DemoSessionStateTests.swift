import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppSessionStateTests: XCTestCase {
    func testShowingContentSelectsNewestDayAndBuildsSourceDescription() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
        )

        state.beginLoading()
        state.show(content: content)

        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.hasLoadedContent)
        XCTAssertEqual(state.selectedDate, "2024-05-02")
        XCTAssertEqual(state.sourceDescription, "Demo fixture: golden_app_export_sample_small.json")
        XCTAssertEqual(state.message?.title, "Demo data ready")
        XCTAssertEqual(state.presentationState, .demoLoaded)
        XCTAssertEqual(state.sourceSummary.stateTitle, "Demo data loaded")
        XCTAssertEqual(state.sourceSummary.sourceValue, "Demo fixture: golden_app_export_sample_small.json")
        XCTAssertEqual(state.sourceSummary.schemaVersion, "1.0")
    }

    func testSelectionFallsBackToNewestKnownDayAndResetsOnReload() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )

        state.show(content: content)
        state.selectDay("2024-05-02")
        XCTAssertEqual(state.selectedDate, "2024-05-02")

        state.selectDay("2099-01-01")
        XCTAssertEqual(state.selectedDate, "2024-05-02")

        state.show(content: content)
        XCTAssertEqual(state.selectedDate, "2024-05-02")
        XCTAssertEqual(state.sourceDescription, "Imported file: imported_app_export.json")
        XCTAssertEqual(state.presentationState, .importedLoaded)
    }

    func testShowContentClearsActiveInsightsDrilldown() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )
        state.activeDrilldownFilter = .filterDaysToDate("2024-05-01")

        state.show(content: content)

        XCTAssertNil(state.activeDrilldownFilter)
    }

    func testSessionContentProvidesFilteredProjectionVariants() throws {
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )
        let filter = AppExportQueryFilter(fromDate: "2024-05-02", toDate: "2024-05-02")

        let filteredOverview = content.overview(applying: filter)
        let filteredSummaries = content.daySummaries(applying: filter)
        let filteredInsights = content.insights(applying: filter)
        let filteredDetail = content.detail(for: "2024-05-02", applying: filter)
        let excludedDetail = content.detail(for: "2024-05-01", applying: filter)

        XCTAssertEqual(filteredOverview.dayCount, 1)
        XCTAssertEqual(filteredSummaries.map(\.date), ["2024-05-02"])
        XCTAssertEqual(filteredInsights.dateRange?.firstDate, "2024-05-02")
        XCTAssertEqual(filteredInsights.dateRange?.lastDate, "2024-05-02")
        XCTAssertEqual(filteredDetail?.date, "2024-05-02")
        XCTAssertNil(excludedDetail)
    }

    func testSelectDayForDisplayClearsEmptyDaySelection() throws {
        var state = AppSessionState()
        state.show(content: makeContent(exportWith(days: """
        {"date":"2024-05-01","visits":[],"activities":[],"paths":[]},
        {"date":"2024-05-02","visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-02T08:00:00Z","end_time":"2024-05-02T09:00:00Z"}],"activities":[],"paths":[]}
        """)))

        XCTAssertEqual(state.selectedDate, "2024-05-02")

        state.selectDayForDisplay("2024-05-01")

        XCTAssertNil(state.selectedDate)
    }

    func testSelectDayForDisplayFallsBackToFirstContentfulDayForUnknownDate() throws {
        var state = AppSessionState()
        state.show(content: makeContent(exportWith(days: """
        {"date":"2024-05-01","visits":[],"activities":[],"paths":[]},
        {"date":"2024-05-02","visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-02T08:00:00Z","end_time":"2024-05-02T09:00:00Z"}],"activities":[],"paths":[]}
        """)))

        state.selectDayForDisplay("2099-01-01")

        XCTAssertEqual(state.selectedDate, "2024-05-02")
    }

    func testFailureCanPreserveCurrentContentForImportErrors() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )
        state.show(content: content)

        state.showFailure(
            title: "Import failed",
            message: "Unable to decode app export file: broken.json",
            preserveCurrentContent: true
        )

        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.hasLoadedContent)
        XCTAssertEqual(state.selectedDate, "2024-05-02")
        XCTAssertEqual(state.message?.title, "Import failed")
        XCTAssertEqual(state.message?.kind, .error)
        XCTAssertEqual(state.sourceDescription, "Imported file: imported_app_export.json")
        XCTAssertEqual(state.presentationState, .failedWithContent)
        XCTAssertEqual(state.sourceSummary.stateTitle, "Import failed")
    }

    func testFailureWithoutPreservingContentClearsSelection() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
        )
        state.show(content: content)

        state.showFailure(
            title: "Unable to load demo fixture",
            message: "Demo fixture not found",
            preserveCurrentContent: false
        )

        XCTAssertFalse(state.hasLoadedContent)
        XCTAssertNil(state.selectedDate)
        XCTAssertNil(state.sourceDescription)
        XCTAssertEqual(state.message?.title, "Unable to load demo fixture")
        XCTAssertEqual(state.presentationState, .failedWithoutContent)
    }

    func testClearContentReturnsStateToImportFirstIdleMode() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )
        state.show(content: content)
        state.activeDrilldownFilter = .filterDaysToDateRange(fromDate: "2024-05-01", toDate: "2024-05-31")

        state.clearContent()

        XCTAssertFalse(state.hasLoadedContent)
        XCTAssertNil(state.selectedDate)
        XCTAssertNil(state.activeDrilldownFilter)
        XCTAssertEqual(state.presentationState, .idle)
        XCTAssertEqual(state.message?.title, "No location history loaded")
        XCTAssertEqual(state.sourceSummary.sourceValue, "None")
    }

    func testBeginLoadingThenRestoreFailureClearsLoadingState() {
        // Simulates the restoreBookmarkedFile() path: beginLoading → decode error → showFailure.
        var state = AppSessionState()
        state.activeDrilldownFilter = .prefillExportForDate("2024-05-01")
        state.beginLoading()
        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.presentationState, .loading)
        XCTAssertNil(state.activeDrilldownFilter)

        state.showFailure(
            title: "Unable to restore previous import",
            message: "Unable to read app export file: old_import.json",
            preserveCurrentContent: false
        )

        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.hasLoadedContent)
        XCTAssertNil(state.selectedDate)
        XCTAssertEqual(state.presentationState, .failedWithoutContent)
        XCTAssertEqual(state.message?.kind, .error)
        XCTAssertEqual(state.message?.title, "Unable to restore previous import")
    }

    func testClearAfterRestoreFailureResetsToIdleWithInfoMessage() {
        // After a restore failure the user can tap Clear to return to a clean import-first state.
        var state = AppSessionState()
        state.showFailure(
            title: "Unable to restore previous import",
            message: "File missing",
            preserveCurrentContent: false
        )
        XCTAssertEqual(state.presentationState, .failedWithoutContent)

        state.clearContent()

        XCTAssertEqual(state.presentationState, .idle)
        XCTAssertFalse(state.hasLoadedContent)
        XCTAssertNil(state.selectedDate)
        XCTAssertEqual(state.message?.kind, .info)
        XCTAssertEqual(state.message?.title, "No location history loaded")
    }

    func testIdleAndFailureStatesHaveDistinctSourceSummaries() {
        var idleState = AppSessionState()
        XCTAssertEqual(idleState.presentationState, .idle)
        XCTAssertEqual(idleState.sourceSummary.stateTitle, "No location history loaded")
        XCTAssertTrue(idleState.sourceSummary.statusText.contains("LocationHistory2GPX"))

        idleState.showFailure(
            title: "Unable to open location history",
            message: "Unable to decode location history file: broken.json",
            preserveCurrentContent: false
        )

        XCTAssertEqual(idleState.presentationState, .failedWithoutContent)
        XCTAssertEqual(idleState.sourceSummary.stateTitle, "Unable to open location history")
        XCTAssertEqual(idleState.sourceSummary.sourceValue, "None")
    }

    private func loadDemoContent(fixtureName: String, source: AppContentSource) throws -> AppSessionContent {
        let url = try TestSupport.contractFixtureURL(named: fixtureName)
        let export = try AppExportDecoder.decode(contentsOf: url)
        return AppSessionContent(export: export, source: source)
    }

    private func makeContent(_ export: AppExport) -> AppSessionContent {
        AppSessionContent(export: export, source: .importedFile(filename: "test.json"))
    }

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
}
