#if canImport(SwiftUI) && canImport(MapKit)
import XCTest
import CoreLocation
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Covers the per-segment speed layer (PR #37 follow-up) on the Insights
/// overview map (`OverviewMapPathOverlay`) and Export preview hero
/// (`ExportPreviewRenderData.PathOverlay`). Both must carry a
/// `speedSamples` array aligned to their coordinates so the renderer can
/// colour-grade each polyline segment by speed.
@available(iOS 17.0, macOS 14.0, *)
final class PerSegmentSpeedInsightsExportTests: XCTestCase {

    // MARK: - SimplifiedSpeedSampler

    func testSpeedSamplerReturnsAlignedSpeedsForSubsetCoordinates() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Five raw samples 1 s apart, roughly 5 m hops in latitude.
        let raw: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 48.0,        longitude: 11.0),
            CLLocationCoordinate2D(latitude: 48.00005,    longitude: 11.0),
            CLLocationCoordinate2D(latitude: 48.00010,    longitude: 11.0),
            CLLocationCoordinate2D(latitude: 48.00015,    longitude: 11.0),
            CLLocationCoordinate2D(latitude: 48.00020,    longitude: 11.0),
        ]
        let times: [Date?] = (0..<5).map { base.addingTimeInterval(TimeInterval($0)) }
        // Simplified subset (DP would drop the middle points on a straight line).
        let simplified: [CLLocationCoordinate2D] = [raw[0], raw[2], raw[4]]

        let samples = SimplifiedSpeedSampler.speedSamples(
            rawCoords: raw,
            rawTimestamps: times,
            simplifiedCoords: simplified
        )
        XCTAssertNotNil(samples)
        XCTAssertEqual(samples?.count, simplified.count)
        // Each consecutive pair should derive a positive speed (~ 5 m / 2 s ≈ 2.7 m/s).
        XCTAssertGreaterThan(samples?[0] ?? 0, 0)
        XCTAssertGreaterThan(samples?[1] ?? 0, 0)
    }

    func testSpeedSamplerReturnsNilWhenAllTimestampsMissing() {
        let raw: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 48.0, longitude: 11.0),
            CLLocationCoordinate2D(latitude: 48.1, longitude: 11.1),
        ]
        let samples = SimplifiedSpeedSampler.speedSamples(
            rawCoords: raw,
            rawTimestamps: [nil, nil],
            simplifiedCoords: raw
        )
        XCTAssertNil(samples)
    }

    // MARK: - ExportPreviewRenderData per-segment branch

    func testExportPreviewRenderDataExposesSpeedSamplesWhenTimestampsPresent() {
        let coords = (0..<6).map { i in
            DayMapCoordinate(lat: 48.0 + Double(i) * 0.0001, lon: 11.0)
        }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamps: [String?] = (0..<6).map { iso.string(from: base.addingTimeInterval(TimeInterval($0))) }

        let preview = ExportPreviewData(
            waypointAnnotations: [],
            pathOverlays: [
                DayMapPathOverlay(
                    coordinates: coords,
                    activityType: "WALKING",
                    distanceM: 30,
                    timestamps: timestamps
                )
            ],
            fittedRegion: nil,
            hasMapContent: true,
            importedDayCount: 0,
            savedTrackCount: 1
        )

        let render = ExportPreviewRenderData(previewData: preview)
        let overlay = try? XCTUnwrap(render.pathOverlays.first)
        XCTAssertEqual(overlay?.coordinates.count, 6)
        XCTAssertNotNil(overlay?.speedSamples, "expected per-coord speed samples when timestamps align")
        XCTAssertEqual(overlay?.speedSamples?.count, overlay?.coordinates.count)
        // Walking-pace samples should be small but positive (~1 m / 1 s ≈ 1 m/s).
        XCTAssertTrue(overlay?.speedSamples?.allSatisfy { $0 >= 0 } ?? false)
        XCTAssertTrue(overlay?.speedSamples?.contains(where: { $0 > 0 }) ?? false)
    }

    func testExportPreviewRenderDataOmitsSpeedSamplesWithoutTimestamps() {
        let coords = (0..<4).map { i in
            DayMapCoordinate(lat: 48.0 + Double(i) * 0.0001, lon: 11.0)
        }
        let preview = ExportPreviewData(
            waypointAnnotations: [],
            pathOverlays: [
                DayMapPathOverlay(
                    coordinates: coords,
                    activityType: "CYCLING",
                    distanceM: 20,
                    timestamps: []
                )
            ],
            fittedRegion: nil,
            hasMapContent: true,
            importedDayCount: 0,
            savedTrackCount: 1
        )
        let render = ExportPreviewRenderData(previewData: preview)
        XCTAssertNil(render.pathOverlays.first?.speedSamples)
    }

    // MARK: - OverviewMapPathOverlay per-segment branch

    func testOverviewMapPathOverlayCarriesSpeedSamplesFromTimestampedPath() {
        // Build 10 evenly-spaced timestamped points so DP cannot collapse the
        // path down to its endpoints (the slight lat/lon zig keeps perpend-
        // icular distance non-zero at every interior point).
        let pointsJSON = (0..<10).map { i -> String in
            let lat = 48.0 + Double(i) * 0.001
            let lon = 11.0 + Double(i) * 0.001 + (i.isMultiple(of: 2) ? 0.0002 : 0.0)
            return "{\"lat\":\(lat),\"lon\":\(lon),\"time\":\"2024-05-01T08:00:0\(i)Z\"}"
        }.joined(separator: ",")
        let exportData = exportWith(days: """
        {
          "date":"2024-05-01",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"WALKING","distance_m":1000,"points":[\(pointsJSON)]}
          ]
        }
        """)

        let scan = OverviewMapPreparation.scanCandidates(
            for: Set(["2024-05-01"]),
            export: exportData,
            filter: nil
        )
        XCTAssertEqual(scan.candidates.count, 1)
        XCTAssertNotNil(scan.candidates.first?.timestamps,
                        "scan must surface parsed timestamps when path.points carry them")

        let render = OverviewMapPreparation.buildOverlaysFromCandidates(
            candidates: scan.candidates,
            totalPointCount: scan.totalPointCount,
            dataRegion: scan.dataRegion,
            viewportRegion: nil
        )
        let overlay = try? XCTUnwrap(render.pathOverlays.first)
        XCTAssertNotNil(overlay?.speedSamples,
                        "speed-mode renderer requires aligned per-coord speeds")
        XCTAssertEqual(overlay?.speedSamples?.count, overlay?.coordinates.count)
    }

    func testOverviewMapPathOverlayFallsBackWhenSourceLacksTimestamps() {
        // flat_coordinates → no per-point times, the Tempo layer must
        // fall back to the uniform tint (speedSamples == nil).
        let flatPairs = (0..<20).map { i -> String in
            "\(48.0 + Double(i) * 0.001), \(11.0 + Double(i) * 0.001)"
        }.joined(separator: ", ")
        let exportData = exportWith(days: """
        {
          "date":"2024-05-02",
          "visits":[],
          "activities":[],
          "paths":[
            {"activity_type":"DRIVING","distance_m":2000,"points":[],"flat_coordinates":[\(flatPairs)]}
          ]
        }
        """)
        let scan = OverviewMapPreparation.scanCandidates(
            for: Set(["2024-05-02"]),
            export: exportData,
            filter: nil
        )
        XCTAssertEqual(scan.candidates.count, 1)
        XCTAssertNil(scan.candidates.first?.timestamps)

        let render = OverviewMapPreparation.buildOverlaysFromCandidates(
            candidates: scan.candidates,
            totalPointCount: scan.totalPointCount,
            dataRegion: scan.dataRegion,
            viewportRegion: nil
        )
        XCTAssertNil(render.pathOverlays.first?.speedSamples)
    }

    // MARK: - Helpers

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
#endif
