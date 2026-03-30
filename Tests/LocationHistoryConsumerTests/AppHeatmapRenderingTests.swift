import XCTest
import SwiftUI
import MapKit
import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class AppHeatmapRenderingTests: XCTestCase {
    func testCoarserLODProducesFewerAggregatedCellsThanFineLOD() {
        let points = clusteredPoints()

        let macroGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .macro)
        let highGrid = HeatmapGridBuilder.computeGrid(for: points, lod: .high)

        XCTAssertFalse(macroGrid.isEmpty)
        XCTAssertFalse(highGrid.isEmpty)
        XCTAssertLessThan(macroGrid.count, highGrid.count)
    }

    func testVisibleCellsRespectViewportAndSelectionLimit() {
        let points = clusteredPoints()
        let grid = HeatmapGridBuilder.computeGrid(for: points, lod: .medium)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )

        let visible = HeatmapGridBuilder.visibleCells(
            in: grid,
            viewportKey: HeatmapViewportKey(region: region, lod: .medium)
        )

        XCTAssertFalse(visible.isEmpty)
        XCTAssertLessThanOrEqual(visible.count, HeatmapLOD.medium.selectionLimit)
        XCTAssertTrue(visible.allSatisfy { abs($0.coordinate.latitude - 52.52) < 0.2 })
        XCTAssertTrue(visible.allSatisfy { abs($0.coordinate.longitude - 13.405) < 0.2 })
    }

    func testDisplayIntensityLiftsMidAndHighDensity() {
        let low = HeatmapVisualStyle.displayIntensity(for: 0.12)
        let mid = HeatmapVisualStyle.displayIntensity(for: 0.5)
        let high = HeatmapVisualStyle.displayIntensity(for: 0.9)

        XCTAssertGreaterThan(low, 0.15)
        XCTAssertGreaterThan(mid, 0.55)
        XCTAssertGreaterThan(high, 0.9)
        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
    }

    func testFullOpacityControlUsesStrongerHighEndMapping() {
        let full = HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: 0.88,
            normalizedIntensity: 0.95,
            overlayOpacity: 1.0,
            lod: .high
        )
        let reduced = HeatmapVisualStyle.effectiveOpacity(
            cellOpacity: 0.88,
            normalizedIntensity: 0.95,
            overlayOpacity: 0.55,
            lod: .high
        )

        XCTAssertGreaterThan(full, 0.8)
        XCTAssertGreaterThan(full, reduced)
    }

    func testPaletteWarmsAsDensityIncreases() {
        let low = HeatmapPalette.rgb(for: 0.12)
        let mid = HeatmapPalette.rgb(for: 0.55)
        let high = HeatmapPalette.rgb(for: 0.9)

        XCTAssertGreaterThan(mid.green, low.green)
        XCTAssertGreaterThan(high.red, mid.red)
        XCTAssertLessThan(high.blue, mid.blue)
    }

    // MARK: - HeatmapMode enum

    func testHeatmapModeEnumExistsWithRouteAndDensityCases() {
        // Verifies both cases exist and have distinct identifiers
        let route = HeatmapMode.route
        let density = HeatmapMode.density
        XCTAssertNotEqual(route.id, density.id)
        XCTAssertEqual(HeatmapMode.allCases.count, 2)
        XCTAssertTrue(HeatmapMode.allCases.contains(.route))
        XCTAssertTrue(HeatmapMode.allCases.contains(.density))
    }

    func testHeatmapModeLabelKeysAreNonEmpty() {
        for mode in HeatmapMode.allCases {
            XCTAssertFalse(mode.labelKey.isEmpty, "labelKey for \(mode) should not be empty")
        }
    }

    // MARK: - Route Grid Builder

    func testRouteGridBuilderProducesSegmentsFromPaths() {
        let export = makeExportWithPaths()
        let grid = RouteGridBuilder.computeGrid(for: export, step: 0.006)
        // With 10 path points there should be 9 segments -> at least 1 bin
        XCTAssertFalse(grid.isEmpty, "Route grid should contain at least one bin from path data")
    }

    func testRouteGridCoarserStepProducesFewerBinsThanFineStep() {
        let export = makeExportWithPaths()
        let coarse = RouteGridBuilder.computeGrid(for: export, step: 0.08)
        let fine   = RouteGridBuilder.computeGrid(for: export, step: 0.003)
        // Same segments fall into fewer bins at coarser resolution
        XCTAssertLessThanOrEqual(coarse.count, fine.count)
    }

    func testRouteGridBinsAreEmptyWhenNoPathData() {
        let export = makeEmptyExport()
        let grid = RouteGridBuilder.computeGrid(for: export, step: 0.006)
        XCTAssertTrue(grid.isEmpty, "Route grid should be empty when export has no paths or activities")
    }

    func testRouteVisibleSegmentsRespectViewportBounds() {
        let export = makeExportWithPaths()
        let step = HeatmapLOD.medium.routeSegmentStep
        let grid = RouteGridBuilder.computeGrid(for: export, step: step)

        guard !grid.isEmpty else {
            XCTFail("Expected non-empty route grid")
            return
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        let viewportKey = RouteViewportKey(region: region, lod: .medium)
        let segments = RouteGridBuilder.visibleSegments(
            in: grid,
            viewportKey: viewportKey,
            step: step,
            lod: .medium
        )

        XCTAssertFalse(segments.isEmpty, "Visible segments should be non-empty within data bounds")
        XCTAssertLessThanOrEqual(segments.count, HeatmapLOD.medium.routeSelectionLimit)
    }

    func testRouteSegmentLineWidthIncreasesWithIntensity() {
        let export = makeExportWithRepeatedRoute()
        let step = HeatmapLOD.high.routeSegmentStep
        let grid = RouteGridBuilder.computeGrid(for: export, step: step)

        guard !grid.isEmpty else {
            XCTFail("Expected non-empty route grid for repeated route test")
            return
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
        let viewportKey = RouteViewportKey(region: region, lod: .high)
        let segments = RouteGridBuilder.visibleSegments(
            in: grid,
            viewportKey: viewportKey,
            step: step,
            lod: .high
        )

        guard segments.count >= 2 else { return } // nothing to compare

        let sorted = segments.sorted { $0.normalizedIntensity < $1.normalizedIntensity }
        let low = sorted.first!
        let high = sorted.last!
        XCTAssertLessThanOrEqual(low.lineWidth, high.lineWidth,
            "Segments with higher intensity should have larger lineWidth")
    }

    func testRoutePaletteIsClearlyDistinctFromDensityPalette() {
        // Route palette: indigo/violet at low end, white/warm at high end.
        // Density palette: blue at low end, red at high end.
        let routeLow  = RoutePalette.rgb(for: 0.05)
        let routeHigh = RoutePalette.rgb(for: 1.0)
        let densityLow  = HeatmapPalette.rgb(for: 0.05)
        let densityHigh = HeatmapPalette.rgb(for: 1.0)

        // Route low-end is indigo: notable red component distinguishes it from pure-blue density low.
        XCTAssertGreaterThan(routeLow.red, densityLow.red,
            "Route low-end should have more red (indigo) than density low-end (pure blue)")
        // Route high-end converges to white (all channels high); density high-end is red-dominant.
        XCTAssertGreaterThan(routeHigh.green, densityHigh.green,
            "Route high-end (white/warm) should have more green than density high-end (red)")
        XCTAssertGreaterThan(routeHigh.blue, densityHigh.blue,
            "Route high-end (white) should have more blue than density high-end (red)")
        // Density low-end retains strong blue
        XCTAssertGreaterThan(densityLow.blue, densityLow.red)
    }

    // MARK: - RoutePathExtractor

    func testRoutePathExtractorProducesConnectedSequencesFromPaths() {
        let export = makeExportWithPaths()
        let step = HeatmapLOD.high.routeSegmentStep
        let grid = RouteGridBuilder.computeGrid(for: export, step: step)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )
        let viewportKey = RouteViewportKey(region: region, lod: .high)

        let paths = RoutePathExtractor.extract(
            from: export,
            grid: grid,
            step: step,
            lod: .high,
            viewportKey: viewportKey
        )

        XCTAssertFalse(paths.isEmpty, "Extractor should produce at least one RoutePath from path data")
        // Each RoutePath must have at least 2 coordinates (otherwise MapPolyline would fail)
        XCTAssertTrue(paths.allSatisfy { $0.coordinates.count >= 2 },
            "Every extracted RoutePath must have at least 2 coordinates")
    }

    func testRoutePathExtractorGlowWidthIsThreeCoreWidth() {
        let export = makeExportWithPaths()
        let step = HeatmapLOD.medium.routeSegmentStep
        let grid = RouteGridBuilder.computeGrid(for: export, step: step)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        let viewportKey = RouteViewportKey(region: region, lod: .medium)

        let paths = RoutePathExtractor.extract(
            from: export,
            grid: grid,
            step: step,
            lod: .medium,
            viewportKey: viewportKey
        )

        guard !paths.isEmpty else { return }
        for path in paths {
            XCTAssertEqual(path.glowLineWidth, path.coreLineWidth * 3.0, accuracy: 0.001,
                "Glow width must be exactly 3× the core width for each RoutePath")
        }
    }

    // MARK: - Helpers

    private func clusteredPoints() -> [WeightedPoint] {
        var points: [WeightedPoint] = []

        for latOffset in stride(from: -0.03, through: 0.03, by: 0.003) {
            for lonOffset in stride(from: -0.03, through: 0.03, by: 0.003) {
                points.append(WeightedPoint(lat: 52.52 + latOffset, lon: 13.405 + lonOffset, weight: 3))
            }
        }

        for latOffset in stride(from: -0.02, through: 0.02, by: 0.004) {
            for lonOffset in stride(from: -0.02, through: 0.02, by: 0.004) {
                points.append(WeightedPoint(lat: 48.137 + latOffset, lon: 11.575 + lonOffset, weight: 1))
            }
        }

        return points
    }

    private func makeExportWithPaths() -> AppExport {
        // 10 path points as flat_coordinates (9 segments through Berlin)
        var flatPairs: [String] = []
        for i in 0..<10 {
            let lat = 52.50 + Double(i) * 0.005
            let lon = 13.40 + Double(i) * 0.003
            flatPairs.append("\(lat), \(lon)")
        }
        let flatJSON = flatPairs.joined(separator: ", ")
        return decodeExport(daysJSON: """
        [{"date":"2025-01-01","visits":[],"activities":[],"paths":[
          {"activity_type":"walking","distance_m":500,"points":[],"flat_coordinates":[\(flatJSON)]}
        ]}]
        """)
    }

    private func makeExportWithRepeatedRoute() -> AppExport {
        // Same short corridor repeated across 20 days to build high-intensity bins
        var dayJSONParts: [String] = []
        for i in 0..<20 {
            var flatPairs: [String] = []
            for j in 0..<5 {
                let lat = 52.515 + Double(j) * 0.001
                let lon = 13.402 + Double(j) * 0.001
                flatPairs.append("\(lat), \(lon)")
            }
            let flatJSON = flatPairs.joined(separator: ", ")
            let dateStr = String(format: "2025-01-%02d", i + 1)
            dayJSONParts.append("""
            {"date":"\(dateStr)","visits":[],"activities":[],"paths":[
              {"activity_type":"cycling","distance_m":200,"points":[],"flat_coordinates":[\(flatJSON)]}
            ]}
            """)
        }
        return decodeExport(daysJSON: "[\(dayJSONParts.joined(separator: ","))]")
    }

    private func makeEmptyExport() -> AppExport {
        decodeExport(daysJSON: "[]")
    }

    private func decodeExport(daysJSON: String) -> AppExport {
        let json = """
        {
          "schema_version": "1.0",
          "meta": {
            "exported_at": "2025-01-01T00:00:00Z",
            "tool_version": "1.0",
            "source": {},
            "output": {},
            "config": {},
            "filters": {}
          },
          "data": { "days": \(daysJSON) }
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(AppExport.self, from: data)
    }
}
