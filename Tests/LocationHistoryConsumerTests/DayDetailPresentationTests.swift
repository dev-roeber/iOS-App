import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class DayDetailPresentationTests: XCTestCase {
    func testDurationFormattingPrefersHumanReadableOutput() {
        XCTAssertEqual(AppTimeDisplay.duration(25 * 60), "25 min")
        XCTAssertEqual(AppTimeDisplay.duration((2 * 3600) + (5 * 60)), "2 h 5 min")
        XCTAssertNil(AppTimeDisplay.duration(-1))
    }

    func testTimeRangeFormattingAvoidsRawISOStrings() {
        let result = AppTimeDisplay.timeRange(
            start: "2024-05-01T07:15:00Z",
            end: "2024-05-01T08:55:00Z"
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.contains("T") ?? true)
        XCTAssertFalse(result?.contains("Z") ?? true)
        XCTAssertTrue(result?.contains(" – ") ?? false)
    }

    func testVisitPresentationUsesUnknownPlaceFallbackAndNote() throws {
        let detail = try detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[
            {
              "lat":52.52,
              "lon":13.41,
              "start_time":"2024-05-01T09:30:00Z",
              "end_time":"2024-05-01T10:15:00Z",
              "accuracy_m":7.8,
              "source_type":"placeVisit"
            }
          ],
          "activities":[],
          "paths":[]
        }
        """, date: "2024-05-01")

        let visit = try XCTUnwrap(detail.visits.first)
        let presentation = DayDetailPresentation.visitCard(for: visit)

        XCTAssertEqual(presentation.title, "Unknown Place")
        XCTAssertEqual(presentation.durationText, "45 min")
        XCTAssertEqual(presentation.chips.map { $0.text }, ["45 min", "8 m accuracy"])
        XCTAssertEqual(presentation.note, "No semantic place label in the export.")
    }

    func testActivityPresentationShowsDistanceDurationAndAverageSpeedWhenAvailable() throws {
        let detail = try detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[
            {
              "start_time":"2024-05-01T07:15:00Z",
              "end_time":"2024-05-01T07:47:00Z",
              "activity_type":"IN PASSENGER VEHICLE",
              "distance_m":29500,
              "split_from_midnight":false,
              "source_type":"activity"
            }
          ],
          "paths":[]
        }
        """, date: "2024-05-01")

        let activity = try XCTUnwrap(detail.activities.first)
        let presentation = DayDetailPresentation.activityCard(for: activity, unit: .metric)

        XCTAssertEqual(presentation.title, "Car")
        XCTAssertEqual(
            presentation.chips.map { $0.text },
            ["29.5 km", "32 min", "Avg 55.3 km/h"]
        )
    }

    func testRoutePresentationKeepsPointCountAsConcreteMetric() throws {
        let detail = try detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {
              "start_time":"2024-05-01T17:10:00Z",
              "end_time":"2024-05-01T17:34:00Z",
              "activity_type":"WALKING",
              "source_type":"timelinePath",
              "points":[
                {"lat":52.5164,"lon":13.3777,"time":"2024-05-01T17:10:00Z","accuracy_m":5},
                {"lat":52.512,"lon":13.384,"time":"2024-05-01T17:22:00Z","accuracy_m":6},
                {"lat":52.509,"lon":13.392,"time":"2024-05-01T17:34:00Z","accuracy_m":5}
              ]
            }
          ]
        }
        """, date: "2024-05-01")

        let route = try XCTUnwrap(detail.paths.first)
        let presentation = DayDetailPresentation.routeCard(for: route, unit: .metric)

        XCTAssertEqual(presentation.title, "Walking Route")
        XCTAssertEqual(presentation.chips.map { $0.text }, ["3 points", "24 min"])
        XCTAssertNil(presentation.note)
    }

    func testSummaryUsesTravelTimeDistanceAndDominantMode() throws {
        let detail = try detailForDay("""
        {
          "date":"2024-05-01",
          "visits":[
            {
              "lat":52.5208,
              "lon":13.4095,
              "start_time":"2024-05-01T06:10:00Z",
              "end_time":"2024-05-01T07:15:00Z",
              "semantic_type":"HOME",
              "place_id":"fixture-home",
              "accuracy_m":12,
              "source_type":"placeVisit"
            }
          ],
          "activities":[
            {
              "start_time":"2024-05-01T07:15:00Z",
              "end_time":"2024-05-01T07:47:00Z",
              "activity_type":"IN PASSENGER VEHICLE",
              "distance_m":29500,
              "split_from_midnight":false,
              "source_type":"activity"
            },
            {
              "start_time":"2024-05-01T17:10:00Z",
              "end_time":"2024-05-01T17:34:00Z",
              "activity_type":"WALKING",
              "distance_m":1450,
              "split_from_midnight":false,
              "source_type":"activity"
            }
          ],
          "paths":[
            {
              "start_time":"2024-05-01T07:15:00Z",
              "end_time":"2024-05-01T07:47:00Z",
              "activity_type":"IN PASSENGER VEHICLE",
              "distance_m":30100,
              "source_type":"timelinePath",
              "points":[
                {"lat":52.5208,"lon":13.4095,"time":"2024-05-01T07:15:00Z","accuracy_m":8},
                {"lat":52.519,"lon":13.394,"time":"2024-05-01T07:30:00Z","accuracy_m":9},
                {"lat":52.5164,"lon":13.3777,"time":"2024-05-01T07:47:00Z","accuracy_m":7}
              ]
            },
            {
              "start_time":"2024-05-01T17:10:00Z",
              "end_time":"2024-05-01T17:34:00Z",
              "activity_type":"WALKING",
              "distance_m":1450,
              "source_type":"timelinePath",
              "points":[
                {"lat":52.5164,"lon":13.3777,"time":"2024-05-01T17:10:00Z","accuracy_m":5},
                {"lat":52.512,"lon":13.384,"time":"2024-05-01T17:22:00Z","accuracy_m":6},
                {"lat":52.509,"lon":13.392,"time":"2024-05-01T17:34:00Z","accuracy_m":5}
              ]
            }
          ]
        }
        """, date: "2024-05-01")

        let presentation = DayDetailPresentation.summary(detail: detail, unit: .metric)

        XCTAssertEqual(presentation.items.map { $0.label }, ["Visits", "Activities", "Routes", "Distance", "Travel Time"])
        XCTAssertEqual(presentation.items.map { $0.value }, ["1", "2", "2", "31.6 km", "56 min"])
        XCTAssertEqual(presentation.footnote, "Main mode Car  •  1 labeled place")
    }

    private func detailForDay(_ dayJSON: String, date: String) throws -> DayDetailViewState {
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
        return try XCTUnwrap(AppExportQueries.dayDetail(for: date, in: export))
    }
}
