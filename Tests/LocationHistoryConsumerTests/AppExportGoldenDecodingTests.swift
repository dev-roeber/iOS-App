import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class AppExportGoldenDecodingTests: XCTestCase {
    func testDecodesAllGoldenAppExports() throws {
        let files = try TestSupport.contractFixtureURLs(prefix: "golden_app_export_", suffix: ".json")
        XCTAssertFalse(files.isEmpty)

        for fileURL in files {
            let export = try AppExportDecoder.decode(contentsOf: fileURL)
            XCTAssertEqual(export.schemaVersion.rawValue, ContractVersion.currentSchemaVersion, fileURL.lastPathComponent)
            XCTAssertFalse(export.meta.toolVersion.isEmpty, fileURL.lastPathComponent)
        }
    }

    func testDecodesDeterministicContractGoldenAndChecksCoreFields() throws {
        let fileURL = try TestSupport.contractFixtureURL(named: "golden_app_export_contract_gate.json")
        let export = try AppExportDecoder.decode(contentsOf: fileURL)

        XCTAssertEqual(export.schemaVersion.rawValue, "1.0")
        XCTAssertEqual(export.meta.exportedAt, "2024-01-02T03:04:05Z")
        XCTAssertEqual(export.meta.source.zipBasename, "fixture_records_public.json")
        XCTAssertEqual(export.meta.source.inputFormat, "records")
        XCTAssertEqual(export.meta.config.mode, "all")
        XCTAssertEqual(export.meta.config.splitMode, "single")
        XCTAssertEqual(export.meta.filters.limit, 5)
        XCTAssertEqual(export.data.days.count, 3)
    }

    func testDecodesForwardCompatibleAdditiveFieldsFixture() throws {
        let fileURL = try TestSupport.contractFixtureURL(named: "golden_app_export_consumer_forward_compatible_additive_fields.json")
        let export = try AppExportDecoder.decode(contentsOf: fileURL)

        XCTAssertEqual(export.data.days.count, 1)
        XCTAssertEqual(export.data.days[0].activities.count, 1)
        XCTAssertEqual(export.data.days[0].paths.count, 1)
        XCTAssertEqual(export.data.days[0].paths[0].points.count, 2)
        XCTAssertEqual(export.stats?.activities?["WALKING"]?.count, 1)
        XCTAssertEqual(export.meta.config.mode, "paths")
    }

    func testDecodesNewRealisticFixturesAndChecksPurposeSpecificFields() throws {
        let cases: [(String, (AppExport) -> Void)] = [
            ("golden_app_export_multi_day_varied_structure.json", { export in
                XCTAssertEqual(export.data.days.count, 3)
                XCTAssertEqual(export.data.days[0].visits.count, 1)
                XCTAssertEqual(export.data.days[1].activities.first?.activityType, "CYCLING")
                XCTAssertEqual(export.data.days[1].paths.first?.points.count, 3)
                XCTAssertEqual(export.stats?.periods?.first?.days, 3)
            }),
            ("golden_app_export_empty_collections_minimal.json", { export in
                XCTAssertEqual(export.data.days.count, 1)
                XCTAssertTrue(export.data.days[0].visits.isEmpty)
                XCTAssertTrue(export.data.days[0].activities.isEmpty)
                XCTAssertTrue(export.data.days[0].paths.isEmpty)
                XCTAssertEqual(export.stats?.activities?.count, 0)
                XCTAssertEqual(export.stats?.periods?.count, 0)
            }),
            ("golden_app_export_no_days_zero.json", { export in
                XCTAssertTrue(export.data.days.isEmpty)
                XCTAssertEqual(export.stats?.activities?.count, 0)
                XCTAssertEqual(export.stats?.periods?.count, 0)
            }),
        ]

        for (fileName, assertions) in cases {
            let export = try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: fileName))
            assertions(export)
        }
    }

    /// Future-version exports must decode successfully (forward compatibility)
    /// but report `isSupportedByThisBuild == false` so the UI can warn that
    /// some fields may not display. Closed-enum behaviour previously made
    /// every future producer-tool release unopenable on installed app builds —
    /// see audit P0-5.
    func testForwardCompatibleSchemaVersionDecodesAndReportsUnsupported() throws {
        let fileURL = try TestSupport.contractFixtureURL(named: "golden_app_export_sample_small.json")
        let data = try Data(contentsOf: fileURL)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let future = try XCTUnwrap(text.replacingOccurrences(of: "\"schema_version\": \"1.0\"", with: "\"schema_version\": \"9.9\"").data(using: .utf8))

        let export = try AppExportDecoder.decode(data: future)
        XCTAssertEqual(export.schemaVersion.rawValue, "9.9")
        XCTAssertFalse(export.schemaVersion.isSupportedByThisBuild)
    }
}
