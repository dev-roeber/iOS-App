import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class DayDetailContentHierarchyTests: XCTestCase {
    func testPlacesLiveToolsAfterImportedSections() throws {
        let detail = try XCTUnwrap(detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[
            {
              "lat":48.0,
              "lon":11.0,
              "start_time":"2024-05-01T08:00:00Z",
              "end_time":"2024-05-01T09:00:00Z",
              "semantic_type":"HOME"
            }
          ],
          "activities":[
            {
              "start_time":"2024-05-01T09:00:00Z",
              "end_time":"2024-05-01T09:30:00Z",
              "activity_type":"WALKING",
              "distance_m":900
            }
          ],
          "paths":[
            {
              "start_time":"2024-05-01T09:05:00Z",
              "end_time":"2024-05-01T09:25:00Z",
              "activity_type":"WALKING",
              "distance_m":900,
              "points":[
                {"lat":48.0,"lon":11.0,"time":"2024-05-01T09:05:00Z"},
                {"lat":48.001,"lon":11.001,"time":"2024-05-01T09:15:00Z"},
                {"lat":48.002,"lon":11.002,"time":"2024-05-01T09:25:00Z"}
              ]
            }
          ]
        }
        """))

        let hierarchy = DayDetailContentHierarchy(detail: detail, hasLiveLocationTools: true)

        XCTAssertEqual(
            hierarchy.sections,
            [
                .importedMap,
                .metricGrid,
                .actions,
                .segmentControl,
                .overview,
                .timeline,
                .visits,
                .activities,
                .routes,
                .localRecording,
            ]
        )
        XCTAssertEqual(hierarchy.totalDistanceM, 900, accuracy: 0.001)
    }

    func testOmitsEmptySectionsAndTimelineWhenNoValidBoundsExist() throws {
        let detail = try XCTUnwrap(detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[
            {
              "start_time":"2024-05-01T09:00:00Z",
              "activity_type":"WALKING",
              "distance_m":400
            }
          ],
          "paths":[]
        }
        """))

        let hierarchy = DayDetailContentHierarchy(detail: detail, hasLiveLocationTools: false)

        XCTAssertEqual(
            hierarchy.sections,
            [
                .importedMap,
                .metricGrid,
                .actions,
                .segmentControl,
                .overview,
                .activities,
            ]
        )
        XCTAssertNil(hierarchy.timeRange)
    }

    func testBuildsTimeRangeAcrossVisitsActivitiesAndPaths() throws {
        let detail = try XCTUnwrap(detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[
            {
              "lat":48.0,
              "lon":11.0,
              "start_time":"2024-05-01T06:30:00Z",
              "end_time":"2024-05-01T07:00:00Z",
              "semantic_type":"HOME"
            }
          ],
          "activities":[
            {
              "start_time":"2024-05-01T07:30:00Z",
              "end_time":"2024-05-01T08:00:00Z",
              "activity_type":"CYCLING",
              "distance_m":1200
            }
          ],
          "paths":[
            {
              "start_time":"2024-05-01T08:05:00Z",
              "end_time":"2024-05-01T08:45:00Z",
              "activity_type":"CYCLING",
              "distance_m":1200,
              "points":[
                {"lat":48.0,"lon":11.0,"time":"2024-05-01T08:05:00Z"},
                {"lat":48.01,"lon":11.01,"time":"2024-05-01T08:45:00Z"}
              ]
            }
          ]
        }
        """))

        let hierarchy = DayDetailContentHierarchy(detail: detail, hasLiveLocationTools: false)

        XCTAssertEqual(hierarchy.timeRange?.earliest, isoDate("2024-05-01T06:30:00Z"))
        XCTAssertEqual(hierarchy.timeRange?.latest, isoDate("2024-05-01T08:45:00Z"))
    }

    private func detailForDay(_ dayJSON: String) throws -> DayDetailViewState? {
        let json = """
        {
          "schema_version":"1.0",
          "meta":{
            "exported_at":"2024-01-01T00:00:00Z",
            "tool_version":"1.0",
            "source":{},
            "output":{},
            "config":{},
            "filters":{}
          },
          "data":{
            "days":[\(dayJSON)]
          }
        }
        """

        let export = try AppExportDecoder.decode(data: Data(json.utf8))
        return AppExportQueries.dayDetail(for: "2024-05-01", in: export)
    }

    private func isoDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}
