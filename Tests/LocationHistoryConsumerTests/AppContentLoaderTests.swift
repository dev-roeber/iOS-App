import XCTest
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

    // MARK: - Helpers

    private func writeTemp(json: String, filename: String) throws -> URL {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
}
