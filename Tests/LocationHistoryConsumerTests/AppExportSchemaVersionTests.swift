import XCTest
@testable import LocationHistoryConsumer

final class AppExportSchemaVersionTests: XCTestCase {
    func testKnownSchemaDecodesAndIsSupported() throws {
        let data = Data("\"1.0\"".utf8)
        let version = try JSONDecoder().decode(AppExportSchemaVersion.self, from: data)
        XCTAssertEqual(version.rawValue, "1.0")
        XCTAssertTrue(version.isSupportedByThisBuild)
    }

    func testFutureSchemaDecodesButReportsUnsupported() throws {
        let data = Data("\"2.0\"".utf8)
        let version = try JSONDecoder().decode(AppExportSchemaVersion.self, from: data)
        XCTAssertEqual(version.rawValue, "2.0")
        XCTAssertFalse(version.isSupportedByThisBuild)
    }

    func testCustomStringSchemaDecodes() throws {
        let data = Data("\"1.0-beta\"".utf8)
        let version = try JSONDecoder().decode(AppExportSchemaVersion.self, from: data)
        XCTAssertEqual(version.rawValue, "1.0-beta")
        XCTAssertFalse(version.isSupportedByThisBuild)
    }

    func testRoundTripPreservesRawValue() throws {
        let original = AppExportSchemaVersion("1.5")
        let encoded = try JSONEncoder().encode(original)
        let encodedString = String(data: encoded, encoding: .utf8) ?? ""
        XCTAssertTrue(encodedString.contains("1.5"), "Expected encoded JSON to contain \"1.5\", got \(encodedString)")
        let decoded = try JSONDecoder().decode(AppExportSchemaVersion.self, from: encoded)
        XCTAssertEqual(decoded.rawValue, "1.5")
    }

    func testStaticV1_0EqualityWithDecoded() throws {
        let data = Data("\"1.0\"".utf8)
        let decoded = try JSONDecoder().decode(AppExportSchemaVersion.self, from: data)
        XCTAssertEqual(decoded, AppExportSchemaVersion.v1_0)
    }

    func testFullAppExportWithFutureSchemaRoundTrips() throws {
        let json = """
        {
            "schema_version": "9.9",
            "meta": {
                "exported_at": "2026-05-06T00:00:00Z",
                "tool_version": "9.9.0",
                "source": {
                    "zip_basename": null,
                    "zip_path": null,
                    "input_format": null
                },
                "output": {
                    "out_dir": null
                },
                "config": {
                    "mode": null,
                    "split_midnight": null,
                    "split_mode": null,
                    "export_format": null,
                    "input_format": null
                },
                "filters": {
                    "from_date": null,
                    "to_date": null,
                    "year": null,
                    "month": null,
                    "weekday": null,
                    "limit": null,
                    "days": null,
                    "has": null,
                    "max_accuracy_m": null,
                    "activity_types": null,
                    "min_gap_min": null
                }
            },
            "data": {
                "days": []
            }
        }
        """
        let data = Data(json.utf8)
        let export = try AppExportDecoder.decode(data: data)
        XCTAssertEqual(export.schemaVersion.rawValue, "9.9")
        XCTAssertFalse(export.schemaVersion.isSupportedByThisBuild)
    }
}
