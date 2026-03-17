import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppSessionStateTests: XCTestCase {
    func testShowingContentSelectsFirstDayAndBuildsSourceDescription() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .demoFixture(name: AppContentLoader.defaultDemoFixtureName)
        )

        state.beginLoading()
        state.show(content: content)

        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.hasLoadedContent)
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.sourceDescription, "Demo fixture: golden_app_export_sample_small.json")
        XCTAssertEqual(state.message?.title, "Demo data ready")
        XCTAssertEqual(state.presentationState, .demoLoaded)
        XCTAssertEqual(state.sourceSummary.stateTitle, "Demo data loaded")
        XCTAssertEqual(state.sourceSummary.sourceValue, "Demo fixture: golden_app_export_sample_small.json")
        XCTAssertEqual(state.sourceSummary.schemaVersion, "1.0")
    }

    func testSelectionFallsBackToFirstKnownDayAndResetsOnReload() throws {
        var state = AppSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .importedFile(filename: "imported_app_export.json")
        )

        state.show(content: content)
        state.selectDay("2024-05-02")
        XCTAssertEqual(state.selectedDate, "2024-05-02")

        state.selectDay("2099-01-01")
        XCTAssertEqual(state.selectedDate, "2024-05-01")

        state.show(content: content)
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.sourceDescription, "Imported file: imported_app_export.json")
        XCTAssertEqual(state.presentationState, .importedLoaded)
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
        XCTAssertEqual(state.selectedDate, "2024-05-01")
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

        state.clearContent()

        XCTAssertFalse(state.hasLoadedContent)
        XCTAssertNil(state.selectedDate)
        XCTAssertEqual(state.presentationState, .idle)
        XCTAssertEqual(state.message?.title, "No app export loaded")
        XCTAssertEqual(state.sourceSummary.sourceValue, "None")
    }

    func testBeginLoadingThenRestoreFailureClearsLoadingState() {
        // Simulates the restoreBookmarkedFile() path: beginLoading → decode error → showFailure.
        var state = AppSessionState()
        state.beginLoading()
        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.presentationState, .loading)

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
        XCTAssertEqual(state.message?.title, "No app export loaded")
    }

    func testIdleAndFailureStatesHaveDistinctSourceSummaries() {
        var idleState = AppSessionState()
        XCTAssertEqual(idleState.presentationState, .idle)
        XCTAssertEqual(idleState.sourceSummary.stateTitle, "No app export loaded")
        XCTAssertTrue(idleState.sourceSummary.statusText.contains("Open a local app_export.json file"))

        idleState.showFailure(
            title: "Unable to open app export",
            message: "Unable to decode app export file: broken.json",
            preserveCurrentContent: false
        )

        XCTAssertEqual(idleState.presentationState, .failedWithoutContent)
        XCTAssertEqual(idleState.sourceSummary.stateTitle, "Unable to open app export")
        XCTAssertEqual(idleState.sourceSummary.sourceValue, "None")
    }

    private func loadDemoContent(fixtureName: String, source: AppContentSource) throws -> AppSessionContent {
        let url = try TestSupport.contractFixtureURL(named: fixtureName)
        let export = try AppExportDecoder.decode(contentsOf: url)
        return AppSessionContent(export: export, source: source)
    }
}
