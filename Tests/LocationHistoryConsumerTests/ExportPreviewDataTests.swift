import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ExportPreviewDataTests: XCTestCase {
    func testPreviewDataUsesSelectedImportedDaysAndSavedTracks() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[
              {"lat":48.0,"lon":11.0},
              {"lat":48.001,"lon":11.001}
            ]}
          ]
        },
        {
          "date":"2024-05-02",
          "visits":[],
          "activities":[],
          "paths":[]
        }
        """)
        let savedTrack = makeRecordedTrack(dayKey: "2024-05-03")

        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggleRecordedTrack(savedTrack.id)

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: [savedTrack]
        )

        XCTAssertTrue(preview.hasMapContent)
        XCTAssertEqual(preview.importedDayCount, 1)
        XCTAssertEqual(preview.savedTrackCount, 1)
        XCTAssertEqual(preview.pathOverlays.count, 2)
        XCTAssertNotNil(preview.fittedRegion)
    }

    func testPreviewDataOmitsRouteLessSelection() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[]
        }
        """)

        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: []
        )

        XCTAssertFalse(preview.hasMapContent)
        XCTAssertEqual(preview.importedDayCount, 1)
        XCTAssertEqual(preview.savedTrackCount, 0)
        XCTAssertEqual(preview.pathOverlays.count, 0)
        XCTAssertNil(preview.fittedRegion)
    }

    func testPreviewDataAppliesQueryFilterToImportedDaysOnly() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":700,"points":[
              {"lat":48.0,"lon":11.0,"accuracy_m":10},
              {"lat":48.001,"lon":11.001,"accuracy_m":60}
            ]}
          ]
        }
        """)
        let savedTrack = makeRecordedTrack(dayKey: "2024-05-03")

        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")
        selection.toggleRecordedTrack(savedTrack.id)

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: [savedTrack],
            queryFilter: AppExportQueryFilter(maxAccuracyM: 25)
        )

        XCTAssertTrue(preview.hasMapContent)
        XCTAssertEqual(preview.importedDayCount, 1)
        XCTAssertEqual(preview.savedTrackCount, 1)
        XCTAssertEqual(preview.pathOverlays.count, 1)
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
