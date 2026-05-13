#if canImport(SwiftUI) && canImport(MapKit)
import XCTest
import CoreLocation
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

/// Covers the Phase-MapKit-A–Z hardening of `DayMapRenderData`:
/// sanitisation of NaN/Inf/sentinel coords, cached speed segments, and
/// stable IDs for the per-overlay ForEach in `AppDayMapView`.
@available(iOS 17.0, macOS 14.0, *)
final class AppDayMapRenderDataTests: XCTestCase {

    private func makeData(
        paths: [(coords: [(Double, Double)], timestamps: [String?]?, activityType: String?)],
        visits: [(Double, Double, String?)] = []
    ) -> DayMapData {
        let pathOverlays: [DayMapPathOverlay] = paths.map { p in
            DayMapPathOverlay(
                coordinates: p.coords.map { DayMapCoordinate(lat: $0.0, lon: $0.1) },
                activityType: p.activityType,
                distanceM: nil,
                timestamps: p.timestamps ?? Array(repeating: nil, count: p.coords.count)
            )
        }
        let visitAnnotations: [DayMapVisitAnnotation] = visits.map {
            DayMapVisitAnnotation(
                coordinate: DayMapCoordinate(lat: $0.0, lon: $0.1),
                semanticType: $0.2,
                startTime: nil,
                endTime: nil
            )
        }
        return DayMapData(
            visitAnnotations: visitAnnotations,
            pathOverlays: pathOverlays,
            fittedRegion: nil,
            hasMapContent: !pathOverlays.isEmpty || !visitAnnotations.isEmpty
        )
    }

    func testSanitisesNaNAndInfinityCoordinates() {
        let coords: [(Double, Double)] = [
            (52.5, 13.4),
            (.nan, 13.4),
            (52.6, .infinity),
            (52.7, 13.5),
            (-180, -180),  // Apple's invalid sentinel
            (52.8, 13.6),
        ]
        let data = makeData(paths: [(coords, nil, "walk")])
        let render = DayMapRenderData(mapData: data)
        XCTAssertEqual(render.pathOverlays.count, 1)
        let overlay = render.pathOverlays[0]
        // 3 valid out of 6 raw points
        XCTAssertEqual(overlay.coordinates.count, 3)
        XCTAssertTrue(overlay.coordinates.allSatisfy { MapCoordinateGuard.isValid($0) })
    }

    func testSanitisesInvalidVisitCoordinates() {
        let data = makeData(
            paths: [([(52.5, 13.4), (52.6, 13.5)], nil, nil)],
            visits: [
                (52.5, 13.4, "home"),
                (.nan, 13.4, "invalid"),
                (-180, -180, "sentinel"),
                (52.6, 13.5, "work"),
            ]
        )
        let render = DayMapRenderData(mapData: data)
        XCTAssertEqual(render.visitAnnotations.count, 2)
        XCTAssertEqual(render.visitAnnotations.map(\.semanticType), ["home", "work"])
    }

    func testStableIdentifiableIDsAcrossPaths() {
        let data = makeData(paths: [
            ([(52.5, 13.4), (52.51, 13.41)], nil, "walk"),
            ([(52.6, 13.5), (52.61, 13.51)], nil, "bike"),
            ([(52.7, 13.6), (52.71, 13.61)], nil, "drive"),
        ])
        let render = DayMapRenderData(mapData: data)
        let ids = render.pathOverlays.map(\.id)
        // IDs must be unique and align with insertion order so the SwiftUI
        // `ForEach(renderData.pathOverlays)` produces stable view identity.
        XCTAssertEqual(ids, [0, 1, 2])
        XCTAssertEqual(Set(ids).count, 3)
    }

    func testSpeedSegmentsArePrecomputedAndAlignedToSanitisedCoords() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let t0 = iso.string(from: now)
        let t1 = iso.string(from: now.addingTimeInterval(2))
        let t2 = iso.string(from: now.addingTimeInterval(4))
        let t3 = iso.string(from: now.addingTimeInterval(6))
        // Inject one NaN coord with a corresponding timestamp — both must
        // be dropped together so sample alignment for speed stays correct.
        let data = makeData(paths: [(
            [(52.5, 13.4), (.nan, 13.4), (52.501, 13.401), (52.502, 13.402)],
            [t0, t1, t2, t3],
            "bike"
        )])
        let render = DayMapRenderData(mapData: data)
        let overlay = render.pathOverlays[0]
        XCTAssertEqual(overlay.coordinates.count, 3)
        XCTAssertEqual(overlay.speedSamples.count, 3)
        // Speed segments precomputed at init; not empty for ≥2 timed samples.
        XCTAssertFalse(overlay.speedSegments.isEmpty)
        XCTAssertLessThanOrEqual(overlay.speedSegments.count, overlay.coordinates.count - 1)
    }

    func testEmptyPathDoesNotCrash() {
        let data = makeData(paths: [([], nil, nil)])
        let render = DayMapRenderData(mapData: data)
        XCTAssertEqual(render.pathOverlays.count, 1)
        XCTAssertTrue(render.pathOverlays[0].coordinates.isEmpty)
        XCTAssertTrue(render.pathOverlays[0].speedSegments.isEmpty)
    }

    func testSingleValidCoordinateProducesNoSpeedSegments() {
        let data = makeData(paths: [([(52.5, 13.4)], nil, "walk")])
        let render = DayMapRenderData(mapData: data)
        XCTAssertEqual(render.pathOverlays[0].coordinates.count, 1)
        XCTAssertTrue(render.pathOverlays[0].speedSegments.isEmpty)
    }
}
#endif
