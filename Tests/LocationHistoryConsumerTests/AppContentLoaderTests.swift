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

    func testJsonNotFoundInZipErrorDescriptionMentionsFile() throws {
        let zipURL = try makeZip(entries: ["other.json": Data("{}".utf8)])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        do {
            _ = try AppContentLoader.loadImportedContent(from: zipURL)
            XCTFail("Expected jsonNotFoundInZip error")
        } catch let error as AppContentLoaderError {
            let description = try XCTUnwrap(error.errorDescription)
            XCTAssertTrue(
                description.contains("app_export.json"),
                "Error description should mention app_export.json. Got: \(description)"
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

    func testZipWithGoogleTimelineFormat_throwsUnsupportedFormat() throws {
        // ZIP containing an app_export.json that is actually a Google Timeline array
        let googleJson = Data("[{}]".utf8)
        let zipURL = try makeZip(entries: ["app_export.json": googleJson])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        XCTAssertThrowsError(try AppContentLoader.loadImportedContent(from: zipURL)) { error in
            guard case AppContentLoaderError.unsupportedFormat = error else {
                XCTFail("Expected unsupportedFormat but got: \(error)")
                return
            }
        }
    }

    // MARK: - Helpers

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
