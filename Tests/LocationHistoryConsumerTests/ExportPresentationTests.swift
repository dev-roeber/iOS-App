import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ExportPresentationTests: XCTestCase {
    func testReadinessHandlesEmptySelection() {
        let readiness = ExportPresentation.readiness(
            selection: ExportSelectionState(),
            summaries: [],
            recordedTracks: []
        )
        XCTAssertEqual(readiness, .nothingSelected)
        XCTAssertEqual(
            ExportPresentation.helperMessage(
                selection: ExportSelectionState(),
                summaries: [],
                recordedTracks: [],
                format: .gpx
            ),
            "Choose at least one imported day or saved track with routes to prepare a GPX file."
        )
    }

    func testReadinessDetectsSelectedDaysWithoutRoutes() {
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        let summaries = makeSummaries(daysJSON: """
        {
          "date":"2024-05-01",
          "visits":[{"lat":48.0,"lon":11.0,"start_time":"2024-05-01T08:00:00Z","end_time":"2024-05-01T08:30:00Z"}],
          "activities":[],
          "paths":[]
        }
        """)

        XCTAssertEqual(
            ExportPresentation.readiness(selection: selection, summaries: summaries, recordedTracks: []),
            .noRoutesSelected(selectedSourceCount: 1)
        )
        XCTAssertEqual(
            ExportPresentation.buttonTitle(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .gpx
            ),
            "Selected item has no routes"
        )
    }

    func testReadinessSummarizesMixedSelection() {
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggle("2024-05-02")
        let summaries = makeSummaries(daysJSON: """
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

        XCTAssertEqual(
            ExportPresentation.readiness(selection: selection, summaries: summaries, recordedTracks: []),
            .ready(
                selectedSourceCount: 2,
                exportableSourceCount: 1,
                routeCount: 2,
                selectedDayCount: 2,
                selectedRecordedTrackCount: 0
            )
        )
        XCTAssertTrue(
            ExportPresentation.helperMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .gpx
            )
            .contains("1 of 2 selected items contribute 2 routes")
        )
        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .gpx
            ),
            "Suggested filename: lh2gpx-2024-05-01_to_2024-05-02.gpx (GPX)."
        )
    }

    func testReadinessCountsOnlyRoutesWithUsablePoints() {
        var selection = ExportSelectionState()
        selection.toggle("2024-05-04")
        let summaries = makeSummaries(daysJSON: """
        {
          "date":"2024-05-04",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[{"lat":48.0,"lon":11.0},{"lat":48.001,"lon":11.001}]},
            {"activity_type":"WALKING","distance_m":0,"points":[]}
          ]
        }
        """)

        XCTAssertEqual(
            ExportPresentation.readiness(selection: selection, summaries: summaries, recordedTracks: []),
            .ready(
                selectedSourceCount: 1,
                exportableSourceCount: 1,
                routeCount: 1,
                selectedDayCount: 1,
                selectedRecordedTrackCount: 0
            )
        )
        XCTAssertEqual(
            ExportPresentation.helperMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .gpx
            ),
            "1 route will be written to the GPX file."
        )
    }

    func testReadinessTreatsSavedTrackAsExportableRouteSource() {
        var selection = ExportSelectionState()
        let recordedTrack = makeRecordedTrack(dayKey: "2024-05-03")
        selection.toggleRecordedTrack(recordedTrack.id)

        XCTAssertEqual(
            ExportPresentation.readiness(
                selection: selection,
                summaries: [],
                recordedTracks: [recordedTrack]
            ),
            .ready(
                selectedSourceCount: 1,
                exportableSourceCount: 1,
                routeCount: 1,
                selectedDayCount: 0,
                selectedRecordedTrackCount: 1
            )
        )
        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: [],
                recordedTracks: [recordedTrack],
                format: .gpx
            ),
            "Suggested filename: lh2gpx-2024-05-03.gpx (GPX)."
        )
    }

    func testFilenameMessageUsesSelectedExportFormatExtension() {
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        let summaries = makeSummaries(daysJSON: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[{"lat":48.0,"lon":11.0},{"lat":48.001,"lon":11.001}]}
          ]
        }
        """)

        XCTAssertEqual(
            ExportPresentation.filenameMessage(
                selection: selection,
                summaries: summaries,
                recordedTracks: [],
                format: .kml
            ),
            "Suggested filename: lh2gpx-2024-05-01.kml (KML)."
        )
    }

    private func makeSummaries(daysJSON: String) -> [DaySummary] {
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
          "data":{"days":[\(daysJSON)]}
        }
        """

        let export = try! AppExportDecoder.decode(data: Data(json.utf8))
        return AppExportQueries.daySummaries(from: export)
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
