import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ExportPresentationTests: XCTestCase {
    func testReadinessHandlesEmptySelection() {
        let readiness = ExportPresentation.readiness(
            importedExport: nil,
            selection: ExportSelectionState(),
            recordedTracks: [],
            mode: .tracks
        )
        XCTAssertEqual(readiness, .nothingSelected)
        XCTAssertEqual(
            ExportPresentation.helperMessage(
                importedExport: nil,
                selection: ExportSelectionState(),
                recordedTracks: [],
                format: .gpx,
                mode: .tracks
            ),
            "Choose at least one imported day or saved track with routes to prepare a GPX file."
        )
    }

    func testTrackReadinessDetectsSelectedDaysWithoutRoutes() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
          "activities":[],
          "paths":[]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        XCTAssertEqual(
            ExportPresentation.readiness(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                mode: .tracks
            ),
            .noExportableContent(selectedSourceCount: 1)
        )
        XCTAssertEqual(
            ExportPresentation.buttonTitle(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                format: .gpx,
                mode: .tracks
            ),
            "Selected item has no routes"
        )
    }

    func testWaypointReadinessTreatsVisitsAsExportableContent() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z","semantic_type":"HOME"}],
          "activities":[],
          "paths":[]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        XCTAssertEqual(
            ExportPresentation.readiness(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                mode: .waypoints
            ),
            .ready(
                selectedSourceCount: 1,
                exportableSourceCount: 1,
                routeCount: 0,
                waypointCount: 1,
                selectedDayCount: 1,
                selectedRecordedTrackCount: 0
            )
        )
        XCTAssertEqual(
            ExportPresentation.helperMessage(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                format: .geoJSON,
                mode: .waypoints
            ),
            "1 waypoint will be written to the GeoJSON file."
        )
    }

    func testMixedReadinessSummarizesRoutesAndWaypoints() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[{"lat":48.0,"lon":11.0},{"lat":48.001,"lon":11.001}]},
            {"activity_type":"WALKING","distance_m":500,"points":[{"lat":48.002,"lon":11.002},{"lat":48.003,"lon":11.003}]}
          ]
        },
        {
          "date":"2024-05-02",
          "visits":[],
          "activities":[],
          "paths":[]
        }
        """)
        let summaries = AppExportQueries.daySummaries(from: export)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggle("2024-05-02")

        XCTAssertEqual(
            ExportPresentation.readiness(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                mode: .both
            ),
            .ready(
                selectedSourceCount: 2,
                exportableSourceCount: 1,
                routeCount: 2,
                waypointCount: 1,
                selectedDayCount: 2,
                selectedRecordedTrackCount: 0
            )
        )
        XCTAssertTrue(
            ExportPresentation.helperMessage(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                format: .gpx,
                mode: .both
            )
            .contains("1 of 2 selected items contribute 2 routes and 1 waypoint")
        )
        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .gpx,
                mode: .both
            ),
            "Suggested filename: lh2gpx-2024-05-01_to_2024-05-02-mixed.gpx (GPX)."
        )
    }

    func testReadinessTreatsSavedTrackAsExportableRouteSource() {
        var selection = ExportSelectionState()
        let recordedTrack = makeRecordedTrack(dayKey: "2024-05-03")
        selection.toggleRecordedTrack(recordedTrack.id)

        XCTAssertEqual(
            ExportPresentation.readiness(
                importedExport: nil,
                selection: selection,
                recordedTracks: [recordedTrack],
                mode: .tracks
            ),
            .ready(
                selectedSourceCount: 1,
                exportableSourceCount: 1,
                routeCount: 1,
                waypointCount: 0,
                selectedDayCount: 0,
                selectedRecordedTrackCount: 1
            )
        )
        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: [],
                recordedTracks: [recordedTrack],
                format: .gpx,
                mode: .tracks
            ),
            "Suggested filename: lh2gpx-2024-05-03.gpx (GPX)."
        )
    }

    func testWaypointModeDoesNotTreatSavedTracksAsWaypointSources() {
        var selection = ExportSelectionState()
        let recordedTrack = makeRecordedTrack(dayKey: "2024-05-03")
        selection.toggleRecordedTrack(recordedTrack.id)

        XCTAssertEqual(
            ExportPresentation.readiness(
                importedExport: nil,
                selection: selection,
                recordedTracks: [recordedTrack],
                mode: .waypoints
            ),
            .noExportableContent(selectedSourceCount: 1)
        )
    }

    func testFilenameMessageUsesModeAndFormatExtension() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
          "activities":[],
          "paths":[]
        }
        """)
        let summaries = AppExportQueries.daySummaries(from: export)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .kml,
                mode: .waypoints
            ),
            "Suggested filename: lh2gpx-2024-05-01-waypoints.kml (KML)."
        )
    }

    func testCsvReadinessCanUseWaypointContentViaBothModeProjection() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
          "activities":[],
          "paths":[]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        XCTAssertEqual(
            ExportPresentation.buttonTitle(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                format: .csv,
                mode: .both
            ),
            "Export 1 item as CSV"
        )
        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: AppExportQueries.daySummaries(from: export),
                recordedTracks: [],
                format: .csv,
                mode: .both
            ),
            "Suggested filename: lh2gpx-2024-05-01-mixed.csv (CSV)."
        )
    }

    func testHelperMessageReflectsExplicitRouteSubsetCounts() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[{"lat":48.0,"lon":11.0,"time":"2024-05-01T08:00:00Z","accuracy_m":10},{"lat":48.001,"lon":11.001,"time":"2024-05-01T08:10:00Z","accuracy_m":8}]},
            {"activity_type":"CYCLING","distance_m":1200,"points":[{"lat":48.01,"lon":11.01,"time":"2024-05-01T09:00:00Z","accuracy_m":6},{"lat":48.02,"lon":11.02,"time":"2024-05-01T09:15:00Z","accuracy_m":5}]}
          ]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggleRoute(day: "2024-05-01", routeIndex: 1)

        XCTAssertEqual(
            ExportPresentation.helperMessage(
                importedExport: export,
                selection: selection,
                recordedTracks: [],
                format: .gpx,
                mode: .tracks
            ),
            "1 route will be written to the GPX file."
        )
    }

    private func exportWith(days jsonDays: String) -> AppExport {
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
          "data":{"days":[\(jsonDays)]}
        }
        """
        return try! AppExportDecoder.decode(data: Data(json.utf8))
    }

    private func makeRecordedTrack(dayKey: String) -> RecordedTrack {
        let formatter = ISO8601DateFormatter()
        let start = formatter.date(from: "\(dayKey)T08:00:00Z")!
        let end = formatter.date(from: "\(dayKey)T08:30:00Z")!
        return RecordedTrack(
            startedAt: start,
            endedAt: end,
            dayKey: dayKey,
            distanceM: 700,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(
                    latitude: 48.0,
                    longitude: 11.0,
                    timestamp: start,
                    horizontalAccuracyM: 5
                ),
                RecordedTrackPoint(
                    latitude: 48.001,
                    longitude: 11.001,
                    timestamp: end,
                    horizontalAccuracyM: 5
                )
            ]
        )
    }
}
