import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Structural tests that verify the data model layer used by landscape-aware
/// views returns correct results regardless of orientation.
///
/// Real SwiftUI UI tests are not possible on Linux; these tests cover the
/// presentation logic that feeds both portrait and landscape layouts.
final class LandscapeLayoutTests: XCTestCase {

    // MARK: - DayDetailPresentation

    func testSummaryItemsAreOrientationIndependent() throws {
        let detail = try makeDetail(visits: 2, activities: 1, paths: 1, distanceM: 5000)

        let presentation = DayDetailPresentation.summary(detail: detail, unit: .metric)

        // Both portrait and landscape columns rely on the same summary items.
        XCTAssertEqual(presentation.items.first(where: { $0.label == "Visits" })?.value, "2")
        XCTAssertEqual(presentation.items.first(where: { $0.label == "Activities" })?.value, "1")
        XCTAssertEqual(presentation.items.first(where: { $0.label == "Routes" })?.value, "1")
        XCTAssertEqual(presentation.items.first(where: { $0.label == "Distance" })?.value, "5.0 km")
    }

    func testSummaryWithNoDistanceOmitsDistanceItem() throws {
        let detail = try makeDetail(visits: 1, activities: 0, paths: 0, distanceM: 0)

        let presentation = DayDetailPresentation.summary(detail: detail, unit: .metric)

        XCTAssertNil(presentation.items.first(where: { $0.label == "Distance" }))
    }

    func testVisitCardPresentationIsStable() throws {
        let detail = try makeDetail(visits: 1, activities: 0, paths: 0, distanceM: 0)

        let visit = try XCTUnwrap(detail.visits.first)
        let card = DayDetailPresentation.visitCard(for: visit)

        XCTAssertFalse(card.title.isEmpty,
            "Visit card title must not be empty — used in both portrait and landscape layouts.")
    }

    func testActivityCardPresentationIsStable() throws {
        let detail = try makeDetailWithActivity()

        let activity = try XCTUnwrap(detail.activities.first)
        let card = DayDetailPresentation.activityCard(for: activity, unit: .metric)

        XCTAssertFalse(card.title.isEmpty,
            "Activity card title must not be empty — used in both portrait and landscape layouts.")
        XCTAssertFalse(card.chips.isEmpty,
            "Activity card chips must be non-empty — displayed in scrollable content column.")
    }

    func testRouteCardPresentationIsStable() throws {
        let detail = try makeDetailWithRoute()

        let route = try XCTUnwrap(detail.paths.first)
        let card = DayDetailPresentation.routeCard(for: route, unit: .metric)

        XCTAssertFalse(card.title.isEmpty,
            "Route card title must not be empty — used in both portrait and landscape layouts.")
        XCTAssertTrue(card.chips.contains(where: { $0.text.contains("point") }),
            "Route card should include point count chip visible in the scrollable content column.")
    }

    // MARK: - DayListPresentation

    func testFilteredSummariesReturnConsistentResultsForLandscapeList() throws {
        let summaries = try makeSummaries(count: 5)

        let all = DayListPresentation.filteredSummaries(summaries, query: "", filter: .empty, favorites: [])
        let filtered = DayListPresentation.filteredSummaries(summaries, query: "2024-05-03", filter: .empty, favorites: [])

        // Portrait and landscape both render from the same filtered list.
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(filtered.count, 1)
    }

    func testAvailableFilterChipsAreStableAcrossOrientations() throws {
        let summaries = try makeSummaries(count: 3)

        let chips = DayListPresentation.availableFilterChips(summaries: summaries, favorites: [])

        // Filter chips appear in the same section regardless of orientation.
        XCTAssertFalse(chips.isEmpty || chips.count > DayListFilterChip.allCases.count,
            "Chip count must stay within expected bounds in any orientation.")
    }

    // MARK: - Helpers

    private func makeDetail(
        visits: Int,
        activities: Int,
        paths: Int,
        distanceM: Double
    ) throws -> DayDetailViewState {
        let visitObjects = (0..<visits).map { i -> String in
            """
            {
              "lat": 52.5\(i),
              "lon": 13.4\(i),
              "start_time": "2024-05-01T0\(i):00:00Z",
              "end_time": "2024-05-01T0\(i + 1):00:00Z",
              "accuracy_m": 10,
              "source_type": "placeVisit"
            }
            """
        }.joined(separator: ",")

        let pathObjects = (0..<paths).map { i -> String in
            let dist = paths > 0 ? distanceM / Double(paths) : 0
            return """
            {
              "start_time": "2024-05-01T10:00:00Z",
              "end_time": "2024-05-01T10:30:00Z",
              "activity_type": "WALKING",
              "distance_m": \(dist),
              "source_type": "timelinePath",
              "points": [
                {"lat": 52.51, "lon": 13.38, "time": "2024-05-01T10:00:00Z", "accuracy_m": 5},
                {"lat": 52.52, "lon": 13.39, "time": "2024-05-01T10:30:00Z", "accuracy_m": 5}
              ]
            }
            """
        }.joined(separator: ",")

        let activityObjects = (0..<activities).map { i -> String in
            """
            {
              "start_time": "2024-05-01T1\(i):00:00Z",
              "end_time": "2024-05-01T1\(i):15:00Z",
              "activity_type": "WALKING",
              "distance_m": 1000,
              "split_from_midnight": false,
              "source_type": "activity"
            }
            """
        }.joined(separator: ",")

        return try decodeDetail(visits: visitObjects, activities: activityObjects, paths: pathObjects)
    }

    private func makeDetailWithActivity() throws -> DayDetailViewState {
        let activity = """
        {
          "start_time": "2024-05-01T07:15:00Z",
          "end_time": "2024-05-01T07:47:00Z",
          "activity_type": "IN PASSENGER VEHICLE",
          "distance_m": 29500,
          "split_from_midnight": false,
          "source_type": "activity"
        }
        """
        return try decodeDetail(visits: "", activities: activity, paths: "")
    }

    private func makeDetailWithRoute() throws -> DayDetailViewState {
        let path = """
        {
          "start_time": "2024-05-01T17:10:00Z",
          "end_time": "2024-05-01T17:34:00Z",
          "activity_type": "WALKING",
          "source_type": "timelinePath",
          "points": [
            {"lat": 52.5164, "lon": 13.3777, "time": "2024-05-01T17:10:00Z", "accuracy_m": 5},
            {"lat": 52.512,  "lon": 13.384,  "time": "2024-05-01T17:22:00Z", "accuracy_m": 6},
            {"lat": 52.509,  "lon": 13.392,  "time": "2024-05-01T17:34:00Z", "accuracy_m": 5}
          ]
        }
        """
        return try decodeDetail(visits: "", activities: "", paths: path)
    }

    private func decodeDetail(visits: String, activities: String, paths: String) throws -> DayDetailViewState {
        let visitsJSON   = visits.isEmpty   ? "[]" : "[\(visits)]"
        let activitiesJSON = activities.isEmpty ? "[]" : "[\(activities)]"
        let pathsJSON    = paths.isEmpty    ? "[]" : "[\(paths)]"

        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "exported_at": "2024-01-01T00:00:00Z",
            "tool_version": "1.0",
            "source": {},
            "output": {},
            "config": {},
            "filters": {}
          },
          "data": {
            "days": [
              {
                "date": "2024-05-01",
                "visits": \(visitsJSON),
                "activities": \(activitiesJSON),
                "paths": \(pathsJSON)
              }
            ]
          }
        }
        """
        let export = try AppExportDecoder.decode(data: Data(json.utf8))
        return try XCTUnwrap(AppExportQueries.dayDetail(for: "2024-05-01", in: export))
    }

    private func makeSummaries(count: Int) throws -> [DaySummary] {
        let days = (1...count).map { i -> String in
            let day = String(format: "%02d", i)
            return """
            {
              "date": "2024-05-\(day)",
              "visits": [
                {
                  "lat": 52.5,
                  "lon": 13.4,
                  "start_time": "2024-05-\(day)T09:00:00Z",
                  "end_time": "2024-05-\(day)T10:00:00Z",
                  "accuracy_m": 10,
                  "source_type": "placeVisit"
                }
              ],
              "activities": [],
              "paths": []
            }
            """
        }.joined(separator: ",")

        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "exported_at": "2024-01-01T00:00:00Z",
            "tool_version": "1.0",
            "source": {},
            "output": {},
            "config": {},
            "filters": {}
          },
          "data": {
            "days": [\(days)]
          }
        }
        """
        let export = try AppExportDecoder.decode(data: Data(json.utf8))
        return AppExportQueries.daySummaries(from: export)
    }
}
