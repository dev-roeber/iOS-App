import XCTest
@testable import LocationHistoryConsumerDemoSupport

final class DemoDataLoaderTests: XCTestCase {
    func testLoadsDefaultDemoFixtureAndBuildsOverview() throws {
        let content = try DemoDataLoader.loadDefaultContent()

        XCTAssertEqual(content.overview.schemaVersion, "1.0")
        XCTAssertEqual(content.overview.inputFormat, "records")
        XCTAssertEqual(content.overview.dayCount, 2)
        XCTAssertEqual(content.daySummaries.map(\.date), ["2024-05-01", "2024-05-02"])
        XCTAssertEqual(content.selectedDate, "2024-05-01")
        XCTAssertEqual(content.source, .bundledFixture(name: DemoDataLoader.defaultFixtureName))
    }

    func testMissingFixtureFailsClearly() {
        XCTAssertThrowsError(try DemoDataLoader.loadContent(named: "does_not_exist")) { error in
            XCTAssertEqual(error.localizedDescription, "Demo fixture not found: does_not_exist.json")
        }
    }

    func testLoadsImportedAppExportFile() throws {
        let sourceURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let importedURL = try copyFixtureToTemporaryFile(named: "imported_app_export.json", from: sourceURL)

        let content = try DemoDataLoader.loadImportedContent(from: importedURL)

        XCTAssertEqual(content.overview.schemaVersion, "1.0")
        XCTAssertEqual(content.daySummaries.map(\.date), ["2024-05-01", "2024-05-02"])
        XCTAssertEqual(content.source, .importedFile(filename: "imported_app_export.json"))
    }

    func testImportedInvalidJSONFailsClearly() throws {
        let invalidURL = try temporaryFileURL(named: "broken_app_export.json")
        try Data("{".utf8).write(to: invalidURL)

        XCTAssertThrowsError(try DemoDataLoader.loadImportedContent(from: invalidURL)) { error in
            XCTAssertEqual(error.localizedDescription, "Unable to decode app export file: broken_app_export.json")
        }
    }

    func testMissingImportedFileFailsClearly() throws {
        let missingURL = temporaryDirectoryURL().appendingPathComponent("missing_app_export.json")

        XCTAssertThrowsError(try DemoDataLoader.loadImportedContent(from: missingURL)) { error in
            XCTAssertEqual(error.localizedDescription, "Unable to read app export file: missing_app_export.json")
        }
    }

    private func copyFixtureToTemporaryFile(named name: String, from sourceURL: URL) throws -> URL {
        let destinationURL = try temporaryFileURL(named: name)
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL)
        return destinationURL
    }

    private func temporaryFileURL(named name: String) throws -> URL {
        let directory = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    private func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
