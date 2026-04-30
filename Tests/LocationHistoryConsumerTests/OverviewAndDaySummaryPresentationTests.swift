import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class OverviewAndDaySummaryPresentationTests: XCTestCase {
    func testOverviewPresentationAddsDateWindowAndExportableRouteContext() throws {
        let export = try export(daysJSON: """
        [
          {
            "date":"2024-05-01",
            "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
            "activities":[{"start_time":"2024-05-01T08:30:00Z","end_time":"2024-05-01T09:00:00Z","activity_type":"WALKING","distance_m":1200}],
            "paths":[{"activity_type":"WALKING","distance_m":1200,"points":[{"lat":48.0,"lon":11.0},{"lat":48.01,"lon":11.01}]}]
          },
          {
            "date":"2024-05-02",
            "visits":[],
            "activities":[],
            "paths":[{"activity_type":"WALKING","distance_m":100,"points":[{"lat":48.0,"lon":11.0}]}]
          }
        ]
        """)

        let overview = AppExportQueries.overview(from: export)
        let summaries = AppExportQueries.daySummaries(from: export)
        let presentation = OverviewPresentation.section(overview: overview, daySummaries: summaries)

        XCTAssertTrue(presentation.subtitle.contains("2024"))
        XCTAssertTrue(presentation.subtitle.contains("2 active days"))
        XCTAssertEqual(presentation.stats.first(where: { $0.id == "days" })?.note, "2 with recorded entries")
        XCTAssertEqual(presentation.stats.first(where: { $0.id == "visits" })?.note, "0.5 per active day")
        XCTAssertEqual(presentation.stats.first(where: { $0.id == "routes" })?.note, "1 exportable · 3 pts")
    }

    func testDaySummaryRowPresentationExplainsExportCleanupInListContext() throws {
        let summary = try daySummaries(daysJSON: """
        [
          {
            "date":"2024-05-01",
            "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
            "activities":[{"start_time":"2024-05-01T08:30:00Z","end_time":"2024-05-01T09:00:00Z","activity_type":"WALKING","distance_m":1200}],
            "paths":[
              {"activity_type":"WALKING","distance_m":1200,"points":[{"lat":48.0,"lon":11.0},{"lat":48.01,"lon":11.01}]},
              {"activity_type":"WALKING","distance_m":100,"points":[{"lat":48.0,"lon":11.0}]}
            ]
          }
        ]
        """).first!

        let presentation = DaySummaryRowPresentationBuilder.presentation(
            for: summary,
            unit: .metric,
            context: .list
        )

        XCTAssertFalse(presentation.dateText.contains("2024-05-01"))
        XCTAssertTrue(presentation.dateText.contains("2024"))
        XCTAssertEqual(presentation.placeText, "1 visit")
        XCTAssertEqual(presentation.routeText, "2 routes")
        XCTAssertNotNil(presentation.timeRangeText)
        XCTAssertEqual(
            presentation.metrics.map { $0.text },
            ["1 visit", "2 routes", "1 activity", "1.3 km"]
        )
    }

    func testDaySummaryRowPresentationUsesExportRouteTextWhenNoGeometryIsExportable() throws {
        let summary = try daySummaries(daysJSON: """
        [
          {
            "date":"2024-05-01",
            "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
            "activities":[],
            "paths":[]
          }
        ]
        """).first!

        let presentation = DaySummaryRowPresentationBuilder.presentation(
            for: summary,
            unit: .metric,
            context: .export
        )

        XCTAssertEqual(
            presentation.routeText,
            "No exportable routes"
        )
        XCTAssertEqual(presentation.placeText, "1 visit")
        XCTAssertEqual(presentation.metrics.map { $0.text }, ["1 visit", "0 routes"])
    }

    private func export(daysJSON: String) throws -> AppExport {
        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "tool_version": "test",
            "exported_at": "2026-03-19T00:00:00Z",
            "source": {
              "zip_basename": "test.zip",
              "input_format": "records"
            },
            "output": {},
            "config": {
              "mode": "paths",
              "split_mode": "single"
            },
            "filters": {}
          },
          "data": {
            "days": \(daysJSON)
          },
          "stats": {
            "activities": {},
            "periods": []
          }
        }
        """

        return try AppExportDecoder.decode(data: Data(json.utf8))
    }

    private func daySummaries(daysJSON: String) throws -> [DaySummary] {
        AppExportQueries.daySummaries(from: try export(daysJSON: daysJSON))
    }
}
