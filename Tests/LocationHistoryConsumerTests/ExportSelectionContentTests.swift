import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ExportSelectionContentTests: XCTestCase {
    func testExportDaysMergeImportedDaysAndSelectedRecordedTracks() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {
              "activity_type":"WALKING",
              "distance_m":700,
              "points":[
                {"lat":48.0,"lon":11.0,"time":"2024-05-01T08:00:00Z","accuracy_m":10},
                {"lat":48.001,"lon":11.001,"time":"2024-05-01T08:10:00Z","accuracy_m":8}
              ]
            }
          ]
        }
        """)
        let savedTrack = makeRecordedTrack(dayKey: "2024-05-03")

        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggleRecordedTrack(savedTrack.id)

        let exportedDays = ExportSelectionContent.exportDays(
            importedExport: export,
            selection: selection,
            recordedTracks: [savedTrack]
        )

        XCTAssertEqual(exportedDays.map(\.date), ["2024-05-01", "2024-05-03"])
        XCTAssertEqual(exportedDays[0].paths.count, 1)
        XCTAssertEqual(exportedDays[0].paths[0].points.count, 2)
        XCTAssertEqual(exportedDays[1].paths.count, 1)
        XCTAssertEqual(exportedDays[1].paths[0].activityType, "LIVE TRACK")
        XCTAssertEqual(exportedDays[1].paths[0].points.count, 2)
    }

    func testExportDaysApplyQueryFilterToImportedHistoryOnly() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {
              "activity_type":"WALKING",
              "distance_m":700,
              "points":[
                {"lat":48.0,"lon":11.0,"time":"2024-05-01T08:00:00Z","accuracy_m":10},
                {"lat":48.001,"lon":11.001,"time":"2024-05-01T08:10:00Z","accuracy_m":55}
              ]
            }
          ]
        }
        """)
        let savedTrack = makeRecordedTrack(dayKey: "2024-05-03")

        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggleRecordedTrack(savedTrack.id)

        let exportedDays = ExportSelectionContent.exportDays(
            importedExport: export,
            selection: selection,
            recordedTracks: [savedTrack],
            queryFilter: AppExportQueryFilter(maxAccuracyM: 25)
        )

        XCTAssertEqual(exportedDays.count, 1)
        XCTAssertEqual(exportedDays[0].date, "2024-05-03")
        XCTAssertEqual(exportedDays[0].paths[0].points.count, 2)
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
            captureMode: .backgroundAlways,
            points: [
                RecordedTrackPoint(
                    latitude: 48.1,
                    longitude: 11.1,
                    timestamp: start,
                    horizontalAccuracyM: 5
                ),
                RecordedTrackPoint(
                    latitude: 48.2,
                    longitude: 11.2,
                    timestamp: end,
                    horizontalAccuracyM: 5
                )
            ]
        )
    }
}
