import XCTest
import ZIPFoundation
@testable import LocationHistoryConsumerAppSupport

final class AppContentLoaderTests: XCTestCase {

    // MARK: - Format detection: Google Location History (array root)

    func testRejectsGoogleTimelineFormatWithUnsupportedFormatError() throws {
        // Google Location History exports use a JSON array as root element.
        // This is the format found in files named "location-history.json" from Google Takeout.
        let googleTimelineJson = """
        [
          {
            "startTime": "2024-01-01T08:00:00.000Z",
            "endTime": "2024-01-01T09:00:00.000Z",
            "visit": {
              "hierarchyLevel": "0",
              "topCandidate": {
                "probability": "0.99",
                "semanticType": "HOME",
                "placeID": "ChIJtest",
                "placeLocation": "geo:52.0,13.0"
              }
            }
          }
        ]
        """
        let url = try writeTemp(json: googleTimelineJson, filename: "location-history.json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: url)) { error in
            guard case AppContentLoaderError.unsupportedFormat(let name) = error else {
                XCTFail("Expected unsupportedFormat but got: \(error)")
                return
            }
            XCTAssertTrue(name.contains("location-history.json"), "Error should reference the filename: \(name)")
        }
    }

    func testRejectsMinimalJsonArrayWithUnsupportedFormatError() throws {
        // Any JSON array root (even empty) should be rejected with unsupportedFormat.
        let url = try writeTemp(json: "[]", filename: "empty-array.json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: url)) { error in
            guard case AppContentLoaderError.unsupportedFormat = error else {
                XCTFail("Expected unsupportedFormat but got: \(error)")
                return
            }
        }
    }

    func testUnsupportedFormatErrorDescriptionMentionsRequiredTool() throws {
        let url = try writeTemp(json: "[{}]", filename: "location-history.json")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try AppContentLoader.loadImportedContent(from: url)
            XCTFail("Expected unsupportedFormat error")
        } catch let error as AppContentLoaderError {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertTrue(
                description.contains("LocationHistory2GPX"),
                "Error description should mention the required tool. Got: \(description)"
            )
        }
    }

    // MARK: - Format detection: unknown JSON object

    func testRejectsUnknownJsonObjectWithDecodeFailedError() throws {
        // A JSON object without schema_version must fail with decodeFailed (not unsupportedFormat).
        let url = try writeTemp(json: #"{"foo": "bar"}"#, filename: "unknown.json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: url)) { error in
            guard case AppContentLoaderError.decodeFailed = error else {
                XCTFail("Expected decodeFailed but got: \(error)")
                return
            }
        }
    }


    func testDecodeFailedErrorDescriptionMentionsRequiredTool() throws {
        let url = try writeTemp(json: #"{"foo": "bar"}"#, filename: "unknown.json")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try AppContentLoader.loadImportedContent(from: url)
            XCTFail("Expected decodeFailed error")
        } catch let error as AppContentLoaderError {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertTrue(
                description.contains("LocationHistory2GPX"),
                "Error description should mention the required tool. Got: \(description)"
            )
        }
    }

    // MARK: - userFacingTitle

    func testFileReadFailedHasUserFacingTitle() {
        let error = AppContentLoaderError.fileReadFailed("test.zip")
        XCTAssertFalse(error.userFacingTitle.isEmpty)
        XCTAssertEqual(error.userFacingTitle, "Unable to read file")
    }

    func testUnsupportedFormatHasSpecificUserFacingTitle() {
        let error = AppContentLoaderError.unsupportedFormat("location-history.json")
        XCTAssertEqual(error.userFacingTitle, "Unsupported file format")
    }

    func testDecodeFailedHasSpecificUserFacingTitle() {
        let error = AppContentLoaderError.decodeFailed("export.json")
        XCTAssertEqual(error.userFacingTitle, "File could not be opened")
    }

    func testJsonNotFoundInZipHasSpecificUserFacingTitle() {
        let error = AppContentLoaderError.jsonNotFoundInZip("takeout.zip")
        XCTAssertEqual(error.userFacingTitle, "No export found in ZIP")
    }

    func testJsonNotFoundInZipDescriptionMentionsConversionWorkflow() throws {
        let zipURL = try makeZip(entries: ["readme.txt": Data("hello".utf8)])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try AppContentLoader.loadImportedContent(from: zipURL)
            XCTFail("Expected jsonNotFoundInZip error")
        } catch let error as AppContentLoaderError {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertTrue(
                description.contains("LocationHistory2GPX"),
                "Error description should mention the required tool. Got: \(description)"
            )
        }
    }

    // MARK: - ZIP Import: error cases

    func testZipWithInvalidContent_throwsFileReadFailed() throws {
        // A file with .zip extension that is not a valid ZIP archive → fileReadFailed
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.zip")
        try Data("not a zip file at all".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: url)) { error in
            guard case AppContentLoaderError.fileReadFailed = error else {
                XCTFail("Expected fileReadFailed but got: \(error)")
                return
            }
        }
    }

    func testZipWithNoAppExportJson_throwsJsonNotFoundInZip() throws {
        // A valid ZIP that contains no app_export.json → jsonNotFoundInZip
        let zipURL = try makeZip(entries: ["readme.txt": Data("hello".utf8)])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: zipURL)) { error in
            guard case AppContentLoaderError.jsonNotFoundInZip(let name) = error else {
                XCTFail("Expected jsonNotFoundInZip but got: \(error)")
                return
            }
            XCTAssertTrue(name.hasSuffix(".zip"), "Error should reference the zip filename: \(name)")
        }
    }

    func testJsonNotFoundInZipErrorDescriptionMentionsTool() throws {
        // ZIP with an invalid JSON object (no valid LH2GPX export) → jsonNotFoundInZip.
        // Description must mention the required tool, not a specific filename.
        let zipURL = try makeZip(entries: ["other.json": Data("{}".utf8)])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try AppContentLoader.loadImportedContent(from: zipURL)
            XCTFail("Expected jsonNotFoundInZip error")
        } catch let error as AppContentLoaderError {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertTrue(
                description.contains("LocationHistory2GPX"),
                "Error description should mention the required tool. Got: \(description)"
            )
        }
    }

    // MARK: - ZIP Import: success cases

    func testZipWithAppExportAtRoot_loadsSuccessfully() throws {
        // Valid ZIP with app_export.json at root → loads successfully
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: ["app_export.json": jsonData])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should have loaded day summaries from ZIP")
        guard case .importedFile(let filename) = content.source else {
            XCTFail("Expected importedFile source")
            return
        }
        XCTAssertTrue(filename.hasSuffix(".zip"), "Source filename should be the ZIP: \(filename)")
    }

    func testZipWithAppExportInSubdirectory_loadsSuccessfully() throws {
        // Valid ZIP with app_export.json nested inside a subdirectory
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: ["export/app_export.json": jsonData])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should have loaded day summaries from nested ZIP entry")
    }

    func testZipWithGoogleTimelineFormat_convertsSuccessfully() throws {
        // ZIP containing a Google Timeline JSON array → converted and loaded.
        // Previously this threw; now the app handles Google Timeline ZIPs directly.
        let googleJson = Data("""
        [{"startTime":"2024-05-01T08:00:00Z","endTime":"2024-05-01T09:00:00Z",
          "visit":{"topCandidate":{"semanticType":"HOME","placeLocation":"geo:52.5,13.4"}}}]
        """.utf8)
        let zipURL = try makeZip(entries: ["app_export.json": googleJson])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertNoThrow(try AppContentLoader.loadImportedContent(from: zipURL),
                         "Google Timeline ZIP should now be converted and loaded")
    }

    // MARK: - ZIP Import: Google Timeline conversion

    func testZipWithGoogleTimelineJson_convertsAndLoads() throws {
        let zipURL = try makeZip(entries: ["location-history.json": minimalGoogleTimelineData()])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should convert Google Timeline and produce day summaries")
        guard case .importedFile(let filename) = content.source else {
            XCTFail("Expected importedFile source"); return
        }
        XCTAssertTrue(filename.hasSuffix(".zip"))
    }

    func testZipWithGoogleTimelineInSubdirectory_convertsAndLoads() throws {
        let zipURL = try makeZip(entries: ["Takeout/Location History/location-history.json": minimalGoogleTimelineData()])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should find and convert Google Timeline nested in subdirectory")
    }

    func testZipWithGoogleTimelineAllEntryTypes_convertsSuccessfully() throws {
        let data = Data("""
        [
          {
            "startTime": "2024-05-01T08:00:00.000Z",
            "endTime": "2024-05-01T09:00:00.000Z",
            "visit": {
              "topCandidate": {
                "semanticType": "HOME",
                "placeLocation": "geo:52.5,13.4",
                "placeID": "ChIJtest"
              }
            }
          },
          {
            "startTime": "2024-05-01T09:00:00.000Z",
            "endTime": "2024-05-01T10:00:00.000Z",
            "activity": {
              "topCandidate": {"type": "WALKING"},
              "distanceMeters": 1500.0,
              "start": "geo:52.5,13.4",
              "end": "geo:52.51,13.41"
            }
          },
          {
            "startTime": "2024-05-01T10:00:00.000Z",
            "endTime": "2024-05-01T11:00:00.000Z",
            "timelinePath": [
              {"point": "geo:52.51,13.41", "durationMinutesOffsetFromStartTime": "0"},
              {"point": "geo:52.52,13.42", "durationMinutesOffsetFromStartTime": "30"}
            ]
          }
        ]
        """.utf8)
        let zipURL = try makeZip(entries: ["location-history.json": data])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        let day = try XCTUnwrap(content.daySummaries.first)
        XCTAssertEqual(day.date, "2024-05-01")
        XCTAssertEqual(day.visitCount, 1)
        XCTAssertEqual(day.activityCount, 1)
        XCTAssertEqual(day.pathCount, 1)
    }

    func testZipWithMultipleGoogleTimelines_prefersLocationHistoryJson() throws {
        let zipURL = try makeZip(entries: [
            "location-history.json": minimalGoogleTimelineData(),
            "other-timeline.json": minimalGoogleTimelineData()
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertNoThrow(try AppContentLoader.loadImportedContent(from: zipURL),
                         "Should prefer location-history.json when multiple timelines present")
    }

    func testZipWithMultipleGoogleTimelines_noPreferred_throwsMultipleExports() throws {
        let zipURL = try makeZip(entries: [
            "timeline_a.json": minimalGoogleTimelineData(),
            "timeline_b.json": minimalGoogleTimelineData()
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: zipURL)) { error in
            guard case AppContentLoaderError.multipleExportsInZip = error else {
                XCTFail("Expected multipleExportsInZip but got: \(error)"); return
            }
        }
    }

    func testZipWithLh2gpxExportTakesPrecedenceOverGoogleTimeline() throws {
        // If a ZIP contains both a valid LH2GPX export and a Google Timeline,
        // the LH2GPX export must be used (no conversion needed).
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let lh2gpxData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: [
            "app_export.json": lh2gpxData,
            "location-history.json": minimalGoogleTimelineData()
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        // The LH2GPX fixture has more days than our minimal timeline stub.
        XCTAssertTrue(content.daySummaries.count > 1, "Should have loaded the LH2GPX export, not the minimal stub")
    }

    // MARK: - ZIP Import: filename-agnostic loading

    func testZipWithValidExportButCustomFilename_loadsSuccessfully() throws {
        // Valid LH2GPX export stored under a non-standard filename → still loads.
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: ["my_backup.json": jsonData])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should load export regardless of filename")
    }

    func testZipWithOneValidAndOneInvalidJson_loadsTheValidOne() throws {
        // One valid export + one invalid JSON → loads the valid one without error.
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: [
            "export.json": jsonData,
            "metadata.json": Data(#"{"version": "1.0"}"#.utf8)
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should load the valid export")
    }

    func testZipWithMultipleValidExports_prefersAppExportJson() throws {
        // Multiple valid exports: one named app_export.json → that one is preferred.
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: [
            "app_export.json": jsonData,
            "backup/app_export.json": jsonData
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // Should not throw – the root-level app_export.json is preferred.
        XCTAssertNoThrow(try AppContentLoader.loadImportedContent(from: zipURL))
    }

    func testZipWithMultipleValidExports_noPreferredName_throwsMultipleExportsInZip() throws {
        // Multiple valid exports, none named app_export.json → multipleExportsInZip.
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: [
            "export_a.json": jsonData,
            "export_b.json": jsonData
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: zipURL)) { error in
            guard case AppContentLoaderError.multipleExportsInZip = error else {
                XCTFail("Expected multipleExportsInZip but got: \(error)")
                return
            }
        }
    }

    func testMultipleExportsInZipHasUserFacingTitle() {
        let error = AppContentLoaderError.multipleExportsInZip("archive.zip")
        XCTAssertEqual(error.userFacingTitle, "Multiple exports found in ZIP")
    }

    func testMultipleExportsInZipDescriptionMentionsSingleExport() {
        let error = AppContentLoaderError.multipleExportsInZip("archive.zip")
        let description = error.errorDescription ?? ""
        XCTAssertTrue(
            description.contains("one"),
            "Error description should mention single export expectation. Got: \(description)"
        )
    }

    func testZipIgnoresMacosxResourceForks() throws {
        // __MACOSX/ entries must be ignored even if they have .json extension.
        let fixtureURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let jsonData = try Data(contentsOf: fixtureURL)
        let zipURL = try makeZip(entries: [
            "__MACOSX/._app_export.json": Data("noise".utf8),
            "app_export.json": jsonData
        ])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let content = try AppContentLoader.loadImportedContent(from: zipURL)
        XCTAssertFalse(content.daySummaries.isEmpty, "Should load without being confused by __MACOSX entry")
    }

    func testRealLocationHistoryZipOnDesktop() throws {
        let url = URL(fileURLWithPath: "/Users/sebastian/Desktop/location-history.zip")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("location-history.zip not on Desktop")
        }
        let content = try AppContentLoader.loadImportedContent(from: url)
        XCTAssertGreaterThan(content.daySummaries.count, 0, "Should load days from real Google Timeline ZIP")
    }

    // MARK: - Helpers

    private func minimalGoogleTimelineData() -> Data {
        Data("""
        [
          {
            "startTime": "2024-05-01T08:00:00.000Z",
            "endTime": "2024-05-01T09:00:00.000Z",
            "visit": {
              "topCandidate": {
                "semanticType": "HOME",
                "placeLocation": "geo:52.5,13.4"
              }
            }
          }
        ]
        """.utf8)
    }

    private func writeTemp(json: String, filename: String) throws -> URL {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    private func makeZip(entries: [String: Data]) throws -> URL {
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        let archive: Archive
        do {
            archive = try Archive(url: zipURL, accessMode: .create)
        } catch {
            throw XCTSkip("Could not create test ZIP archive at \(zipURL.path): \(error)")
        }
        for (path, data) in entries {
            let entryData = data
            try archive.addEntry(with: path, type: .file, uncompressedSize: UInt32(entryData.count)) { position, size in
                entryData.subdata(in: position..<(position + size))
            }
        }
        return zipURL
    }
}
