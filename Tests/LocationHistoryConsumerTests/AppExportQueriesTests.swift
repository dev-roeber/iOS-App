import Foundation
import XCTest
@testable import LocationHistoryConsumer

final class AppExportQueriesTests: XCTestCase {
    func testBuildsOverviewFromDeterministicGolden() throws {
        let export = try loadExport(named: "golden_app_export_contract_gate.json")

        let overview = AppExportQueries.overview(from: export)

        XCTAssertEqual(overview.schemaVersion, "1.0")
        XCTAssertEqual(overview.exportedAt, "2024-01-02T03:04:05Z")
        XCTAssertEqual(overview.inputFormat, "records")
        XCTAssertEqual(overview.mode, "all")
        XCTAssertEqual(overview.splitMode, "single")
        XCTAssertEqual(overview.dayCount, 3)
        XCTAssertEqual(overview.totalVisitCount, 8)
        XCTAssertEqual(overview.totalActivityCount, 5)
        XCTAssertEqual(overview.totalPathCount, 5)
        XCTAssertEqual(overview.statsActivityTypes, ["CYCLING", "IN BUS", "IN PASSENGER VEHICLE", "UNKNOWN", "WALKING"])
    }

    func testBuildsDaySummariesInDeterministicDateOrder() throws {
        let export = try loadExport(named: "golden_app_export_multi_day_varied_structure.json")

        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(summaries.map(\.date), ["2024-06-10", "2024-06-11", "2024-06-12"])
        XCTAssertEqual(summaries[0].visitCount, 1)
        XCTAssertEqual(summaries[1].activityCount, 1)
        XCTAssertEqual(summaries[1].pathCount, 1)
        XCTAssertEqual(summaries[1].totalPathPointCount, 3)
        XCTAssertEqual(summaries[1].totalPathDistanceM, 2410.0, accuracy: 0.0001)
        XCTAssertEqual(summaries[2].pathCount, 0)
    }

    func testSortsSummariesEvenWhenDecodedDaysAreNotInOrder() throws {
        let export = try loadExportWithReversedDays(named: "golden_app_export_multi_day_varied_structure.json")

        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(summaries.map(\.date), ["2024-06-10", "2024-06-11", "2024-06-12"])
    }

    func testFindDayAndInclusiveDateRangeSelection() throws {
        let export = try loadExport(named: "golden_app_export_multi_day_varied_structure.json")

        XCTAssertEqual(AppExportQueries.findDay(on: "2024-06-11", in: export)?.activities.count, 1)
        XCTAssertNil(AppExportQueries.findDay(on: "2024-06-13", in: export))

        let filtered = AppExportQueries.days(in: export, from: "2024-06-11", to: "2024-06-12")
        XCTAssertEqual(filtered.map(\.date), ["2024-06-11", "2024-06-12"])
    }

    func testOverviewAndSummariesHandleEmptyCollections() throws {
        let export = try loadExport(named: "golden_app_export_empty_collections_minimal.json")

        let overview = AppExportQueries.overview(from: export)
        let summaries = AppExportQueries.daySummaries(from: export)

        XCTAssertEqual(overview.dayCount, 1)
        XCTAssertEqual(overview.totalVisitCount, 0)
        XCTAssertEqual(overview.totalActivityCount, 0)
        XCTAssertEqual(overview.totalPathCount, 0)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].totalPathPointCount, 0)
        XCTAssertEqual(summaries[0].totalPathDistanceM, 0)
    }

    private func loadExport(named name: String) throws -> AppExport {
        try AppExportDecoder.decode(contentsOf: TestSupport.contractFixtureURL(named: name))
    }

    private func loadExportWithReversedDays(named name: String) throws -> AppExport {
        let url = try TestSupport.contractFixtureURL(named: name)
        let data = try Data(contentsOf: url)
        let rootObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var dataObject = try XCTUnwrap(rootObject["data"] as? [String: Any])
        let days = try XCTUnwrap(dataObject["days"] as? [[String: Any]])
        dataObject["days"] = Array(days.reversed())

        var mutated = rootObject
        mutated["data"] = dataObject

        let mutatedData = try JSONSerialization.data(withJSONObject: mutated, options: [.prettyPrinted, .sortedKeys])
        return try AppExportDecoder.decode(data: mutatedData)
    }
}
