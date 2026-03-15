import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class DayDetailViewStateTests: XCTestCase {
    func testBuildsDayDetailForKnownDate() throws {
        let export = try loadExport(named: "golden_app_export_contract_gate.json")

        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2024-05-01", in: export))

        XCTAssertEqual(detail.date, "2024-05-01")
        XCTAssertEqual(detail.visits.count, 3)
        XCTAssertEqual(detail.activities.count, 2)
        XCTAssertEqual(detail.paths.count, 2)
        XCTAssertEqual(detail.totalPathPointCount, 7)
        XCTAssertTrue(detail.hasContent)
        XCTAssertEqual(detail.visits.first?.semanticType, "HOME")
        XCTAssertEqual(detail.activities.first?.activityType, "WALKING")
        XCTAssertEqual(detail.paths.first?.pointCount, 3)
        XCTAssertEqual(detail.paths.first?.points.first?.time, "2024-05-01T07:20:00Z")
    }

    func testBuildsForwardCompatibleDetailWithoutDependingOnUnknownFields() throws {
        let export = try loadExport(named: "golden_app_export_consumer_forward_compatible_additive_fields.json")

        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2024-07-14", in: export))

        XCTAssertEqual(detail.visits.count, 0)
        XCTAssertEqual(detail.activities.count, 1)
        XCTAssertEqual(detail.paths.count, 1)
        XCTAssertEqual(detail.totalPathPointCount, 2)
        XCTAssertEqual(detail.activities.first?.distanceM, 480.0)
        XCTAssertEqual(detail.paths.first?.points.last?.lon, 13.409)
    }

    func testBuildsEmptyDayDetailWithoutCrashing() throws {
        let export = try loadExport(named: "golden_app_export_empty_collections_minimal.json")

        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2024-03-01", in: export))

        XCTAssertFalse(detail.hasContent)
        XCTAssertTrue(detail.visits.isEmpty)
        XCTAssertTrue(detail.activities.isEmpty)
        XCTAssertTrue(detail.paths.isEmpty)
        XCTAssertEqual(detail.totalPathPointCount, 0)
    }

    func testReturnsNilForMissingDayDetail() throws {
        let export = try loadExport(named: "golden_app_export_sample_small.json")

        XCTAssertNil(AppExportQueries.dayDetail(for: "1999-01-01", in: export))
    }

    private func loadExport(named name: String) throws -> AppExport {
        try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: name))
    }
}
