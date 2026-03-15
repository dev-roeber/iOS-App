import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerDemoSupport

final class DemoSessionStateTests: XCTestCase {
    func testShowingContentSelectsFirstDayAndBuildsSourceDescription() throws {
        var state = DemoSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .bundledFixture(name: DemoDataLoader.defaultFixtureName)
        )

        state.beginLoading()
        state.show(content: content)

        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.hasLoadedContent)
        XCTAssertEqual(state.selectedDate, "2024-05-01")
        XCTAssertEqual(state.sourceDescription, "Demo fixture: golden_app_export_sample_small.json")
        XCTAssertEqual(state.message?.title, "Demo ready")
    }

    func testSelectionFallsBackToFirstKnownDayAndResetsOnReload() throws {
        var state = DemoSessionState()
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
    }

    func testFailureCanPreserveCurrentContentForImportErrors() throws {
        var state = DemoSessionState()
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
    }

    func testFailureWithoutPreservingContentClearsSelection() throws {
        var state = DemoSessionState()
        let content = try loadDemoContent(
            fixtureName: "golden_app_export_sample_small.json",
            source: .bundledFixture(name: DemoDataLoader.defaultFixtureName)
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
    }

    private func loadDemoContent(fixtureName: String, source: DemoContentSource) throws -> DemoContent {
        let url = try TestSupport.contractFixtureURL(named: fixtureName)
        let export = try AppExportDecoder.decode(contentsOf: url)
        return DemoContent(export: export, source: source)
    }
}
