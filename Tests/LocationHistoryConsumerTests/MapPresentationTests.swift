import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class MapPresentationTests: XCTestCase {
    func testDaySectionSummarizesPinsRoutesPointsDistanceAndMissingCoordinates() {
        let detail = try! dayDetail(
            date: "2024-05-01",
            dayJSON: """
            {
              "date":"2024-05-01",
              "visits":[
                {
                  "lat":52.52,
                  "lon":13.40,
                  "start_time":"2024-05-01T08:00:00Z",
                  "end_time":"2024-05-01T09:00:00Z",
                  "semantic_type":"HOME",
                  "accuracy_m":10,
                  "source_type":"placeVisit"
                },
                {
                  "start_time":"2024-05-01T10:00:00Z",
                  "end_time":"2024-05-01T10:30:00Z",
                  "semantic_type":"WORK",
                  "accuracy_m":10,
                  "source_type":"placeVisit"
                }
              ],
              "activities":[],
              "paths":[
                {
                  "start_time":"2024-05-01T09:00:00Z",
                  "end_time":"2024-05-01T09:20:00Z",
                  "activity_type":"WALKING",
                  "distance_m":1500,
                  "source_type":"timelinePath",
                  "points":[
                    {"lat":52.52,"lon":13.40},
                    {"lat":52.521,"lon":13.401},
                    {"lat":52.522,"lon":13.402}
                  ]
                },
                {
                  "start_time":"2024-05-01T12:00:00Z",
                  "end_time":"2024-05-01T12:30:00Z",
                  "activity_type":"IN PASSENGER VEHICLE",
                  "source_type":"timelinePath",
                  "points":[
                    {"lat":52.53,"lon":13.43},
                    {"lat":52.54,"lon":13.44}
                  ]
                }
              ]
            }
            """
        )

        let mapData = DayMapDataExtractor.mapData(from: detail)
        let presentation = MapPresentation.daySection(
            detail: detail,
            mapData: mapData,
            unit: .metric
        )

        XCTAssertEqual(metricText("pins", in: presentation), "1 pin")
        XCTAssertEqual(metricText("routes", in: presentation), "2 routes")
        XCTAssertEqual(metricText("points", in: presentation), "5 pts")
        XCTAssertEqual(metricText("distance", in: presentation), "1.5 km")
        XCTAssertEqual(presentation.legendItems.map { $0.title }, ["Walking", "Car"])
        XCTAssertEqual(presentation.legendItems.map { $0.isOverflow }, [false, false])
        XCTAssertEqual(
            presentation.note,
            "Pins show imported visits and lines show imported route paths. Walking dominates the plotted movement. 1 visit is omitted because coordinates are missing or too short."
        )
    }

    func testExportPreviewSummarizesSourcesDistanceAndDominantMode() {
        let preview = ExportPreviewData(
            waypointAnnotations: [],
            pathOverlays: [
                DayMapPathOverlay(
                    coordinates: [
                        DayMapCoordinate(lat: 48.0, lon: 11.0),
                        DayMapCoordinate(lat: 48.01, lon: 11.01),
                    ],
                    activityType: "WALKING",
                    distanceM: 1000
                ),
                DayMapPathOverlay(
                    coordinates: [
                        DayMapCoordinate(lat: 48.1, lon: 11.1),
                        DayMapCoordinate(lat: 48.2, lon: 11.2),
                        DayMapCoordinate(lat: 48.3, lon: 11.3),
                    ],
                    activityType: "CYCLING",
                    distanceM: 5000
                ),
            ],
            fittedRegion: DayMapRegion(centerLat: 48.15, centerLon: 11.15, spanLat: 0.5, spanLon: 0.5),
            hasMapContent: true,
            importedDayCount: 2,
            savedTrackCount: 1
        )

        let presentation = MapPresentation.exportPreview(preview, unit: .metric, mode: .tracks)

        XCTAssertEqual(metricText("sources", in: presentation), "3 sources")
        XCTAssertEqual(metricText("routes", in: presentation), "2 routes")
        XCTAssertEqual(metricText("points", in: presentation), "5 pts")
        XCTAssertEqual(metricText("distance", in: presentation), "6.0 km")
        XCTAssertEqual(presentation.legendItems.map { $0.title }, ["Cycling", "Walking"])
        XCTAssertEqual(
            presentation.note,
            "Preview uses exportable route paths from 2 imported days and 1 saved track. Cycling contributes the strongest visible route context."
        )
    }

    func testLegendOverflowCollapsesAdditionalRouteModes() {
        let preview = ExportPreviewData(
            waypointAnnotations: [],
            pathOverlays: [
                overlay(type: "WALKING", distance: 3000),
                overlay(type: "CYCLING", distance: 2000),
                overlay(type: "IN BUS", distance: 1000),
                overlay(type: "RUNNING", distance: 500),
            ],
            fittedRegion: DayMapRegion(centerLat: 0, centerLon: 0, spanLat: 1, spanLon: 1),
            hasMapContent: true,
            importedDayCount: 1,
            savedTrackCount: 0
        )

        let presentation = MapPresentation.exportPreview(preview, unit: .metric, mode: .tracks)

        XCTAssertEqual(presentation.legendItems.map { $0.title }, ["Walking", "Cycling", "Bus", "+1 more"])
        XCTAssertEqual(presentation.legendItems.last?.isOverflow, true)
    }

    func testExportPreviewSummarizesWaypointMode() {
        let preview = ExportPreviewData(
            waypointAnnotations: [
                DayMapVisitAnnotation(
                    coordinate: DayMapCoordinate(lat: 48.0, lon: 11.0),
                    semanticType: "HOME",
                    startTime: nil,
                    endTime: nil
                ),
                DayMapVisitAnnotation(
                    coordinate: DayMapCoordinate(lat: 48.1, lon: 11.1),
                    semanticType: "WORK",
                    startTime: nil,
                    endTime: nil
                )
            ],
            pathOverlays: [],
            fittedRegion: DayMapRegion(centerLat: 48.05, centerLon: 11.05, spanLat: 0.2, spanLon: 0.2),
            hasMapContent: true,
            importedDayCount: 1,
            savedTrackCount: 0
        )

        let presentation = MapPresentation.exportPreview(preview, unit: .metric, mode: .waypoints)

        XCTAssertEqual(metricText("sources", in: presentation), "1 source")
        XCTAssertEqual(metricText("waypoints", in: presentation), "2 waypoints")
        XCTAssertEqual(
            presentation.note,
            "Preview uses exportable waypoint locations from 1 imported day."
        )
    }

    private func metricText(_ id: String, in presentation: MapSectionPresentation) -> String? {
        presentation.metrics.first(where: { $0.id == id })?.text
    }

    private func overlay(type: String, distance: Double) -> DayMapPathOverlay {
        DayMapPathOverlay(
            coordinates: [
                DayMapCoordinate(lat: 1, lon: 1),
                DayMapCoordinate(lat: 2, lon: 2),
            ],
            activityType: type,
            distanceM: distance
        )
    }

    private func dayDetail(date: String, dayJSON: String) throws -> DayDetailViewState {
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
          "data":{"days":[\(dayJSON)]}
        }
        """

        let export = try AppExportDecoder.decode(data: Data(json.utf8))
        return try XCTUnwrap(AppExportQueries.dayDetail(for: date, in: export))
    }
}
