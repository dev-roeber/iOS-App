import XCTest
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Map-Train 2: verifies that `ExportPreviewDataBuilder.previewData` drops
/// NaN/Inf/sentinel coordinates at the Foundation layer so neither the
/// region bounds nor the downstream `MapPolyline`/`Marker` render can be
/// handed an invalid `CLLocationCoordinate2D`.
final class ExportPreviewSanitizeTests: XCTestCase {

    func testOutOfRangeAndSentinelCoordsDroppedFromPathOverlays() {
        // 4 raw points: 2 valid, 2 invalid (lat 91 = out of range,
        // (-180,-180) = Apple sentinel). JSON cannot carry NaN/Inf, so we
        // use out-of-range finite values — the validity check rejects both.
        // PathOverlay requires ≥ 2 valid points after filter — survives.
        let export = exportWith(days: """
        {
          "date":"2024-05-01","visits":[],"activities":[],
          "paths":[{
            "activity_type":"WALKING","distance_m":1000,"points":[
              {"lat":48.0,"lon":11.0},
              {"lat":91.0,"lon":11.001},
              {"lat":-180.0,"lon":-180.0},
              {"lat":48.003,"lon":11.003}
            ]
          }]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: [],
            mode: .tracks
        )

        XCTAssertEqual(preview.pathOverlays.count, 1)
        // 2 valid out of 4 raw points
        XCTAssertEqual(preview.pathOverlays[0].coordinates.count, 2)
        XCTAssertEqual(preview.pathOverlays[0].timestamps.count, 2)
        XCTAssertTrue(preview.pathOverlays[0].coordinates.allSatisfy {
            CoordinateValidity.isValid(latitude: $0.lat, longitude: $0.lon)
        })
        // Region bounds must be finite — guarantees no NaN handed to MapKit.
        let region = try? XCTUnwrap(preview.fittedRegion)
        XCTAssertTrue(region?.centerLat.isFinite ?? false)
        XCTAssertTrue(region?.centerLon.isFinite ?? false)
        XCTAssertTrue(region?.spanLat.isFinite ?? false)
        XCTAssertTrue(region?.spanLon.isFinite ?? false)
    }

    func testPathDroppedWhenFewerThanTwoValidPointsRemain() {
        let export = exportWith(days: """
        {
          "date":"2024-05-01","visits":[],"activities":[],
          "paths":[{
            "activity_type":"WALKING","distance_m":1000,"points":[
              {"lat":48.0,"lon":11.0},
              {"lat":91.0,"lon":11.001},
              {"lat":-180.0,"lon":-180.0}
            ]
          }]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: [],
            mode: .tracks
        )

        XCTAssertEqual(preview.pathOverlays.count, 0)
        XCTAssertFalse(preview.hasMapContent)
        XCTAssertNil(preview.fittedRegion)
    }

    func testValidCoordsUnchanged() {
        // Identitäts-Garantie: rein valide Daten bleiben strukturell identisch.
        let export = exportWith(days: """
        {
          "date":"2024-05-01","visits":[],"activities":[],
          "paths":[{
            "activity_type":"WALKING","distance_m":1000,"points":[
              {"lat":48.0,"lon":11.0},
              {"lat":48.001,"lon":11.001},
              {"lat":48.002,"lon":11.002}
            ]
          }]
        }
        """)
        var selection = ExportSelectionState()
        selection.toggle("2024-05-01")

        let preview = ExportPreviewDataBuilder.previewData(
            importedExport: export,
            selection: selection,
            recordedTracks: [],
            mode: .tracks
        )

        XCTAssertEqual(preview.pathOverlays.count, 1)
        XCTAssertEqual(preview.pathOverlays[0].coordinates.count, 3)
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
}
