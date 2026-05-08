// Conditional notes:
// - All sections except #7 are pure Swift / Foundation and run on Linux.
// - Section #7 (`AppHeatmapModel`) gates on `canImport(MapKit)` because the
//   model itself is `#if canImport(SwiftUI) && canImport(MapKit)`. On Linux
//   the section's tests compile out and contribute nothing — the underlying
//   code path is still exercised on macOS/iOS CI runs.

import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

#if canImport(MapKit)
import MapKit
#endif

/// End-to-end coverage for the 2026-05-08 P0 `flatCoordinates` canonicalization
/// refactor. Verifies every consumer that previously walked `Path.points`
/// (sanitizer, queries, distance calculator, map-data extractor, GPX/KML/
/// GeoJSON/CSV builders, GoogleTimelineConverter, AppHeatmapModel) now
/// correctly handles paths shaped as `points: [], flatCoordinates: [lat, lon, …]`.
final class FlatCoordinatesGeometryTests: XCTestCase {

    // MARK: - 1. ExportRouteSanitizer

    func testSanitizerKeepsFlatOnlyPath() throws {
        let path = makeFlatPath(flat: [0, 0, 1, 1])
        let sanitized = try XCTUnwrap(ExportRouteSanitizer.sanitizedPath(path))

        XCTAssertTrue(sanitized.points.isEmpty,
                      "Sanitizer must keep points empty for flat-only paths")
        XCTAssertEqual(sanitized.flatCoordinates, [0, 0, 1, 1])
    }

    func testSanitizerRejectsBothEmpty() {
        let path = makeFlatPath(flat: nil)
        XCTAssertNil(ExportRouteSanitizer.sanitizedPath(path),
                     "A path with empty points and nil flat must be dropped")
    }

    func testSanitizerRejectsTooFewFlat() {
        let path = makeFlatPath(flat: [0, 0])
        XCTAssertNil(ExportRouteSanitizer.sanitizedPath(path),
                     "Less than 4 doubles (one vertex) is not a polyline")
    }

    func testSanitizerRejectsOddFlat() {
        let path = makeFlatPath(flat: [0, 0, 1])
        XCTAssertNil(ExportRouteSanitizer.sanitizedPath(path),
                     "Odd-count flatCoordinates is malformed and must be rejected")
    }

    func testSanitizerStillDedupesPointsPath() throws {
        let duplicate = PathPoint(lat: 48.0, lon: 11.0, time: "2024-05-01T08:00:00Z", accuracyM: nil)
        let unique = PathPoint(lat: 48.001, lon: 11.001, time: "2024-05-01T08:05:00Z", accuracyM: nil)
        let path = Path(
            startTime: nil,
            endTime: nil,
            activityType: "WALKING",
            distanceM: nil,
            sourceType: nil,
            points: [duplicate, duplicate, unique],
            flatCoordinates: nil
        )
        let sanitized = try XCTUnwrap(ExportRouteSanitizer.sanitizedPath(path))
        XCTAssertEqual(sanitized.points.count, 2,
                       "Legacy points-shaped paths must still be deduplicated")
    }

    func testExportablePathCountIncludesFlatOnlyPaths() {
        let pointsPath = Path(
            startTime: nil, endTime: nil, activityType: "WALKING",
            distanceM: nil, sourceType: nil,
            points: [
                PathPoint(lat: 48.0, lon: 11.0, time: nil, accuracyM: nil),
                PathPoint(lat: 48.001, lon: 11.001, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let flatPath = makeFlatPath(flat: [52.5, 13.4, 52.51, 13.41])
        let day = Day(date: "2024-05-01", visits: [], activities: [], paths: [pointsPath, flatPath])

        XCTAssertEqual(ExportRouteSanitizer.exportablePathCount(in: day), 2,
                       "Both points-shaped and flat-shaped paths count as exportable")
    }

    // MARK: - 2. AppExportQueries (dayDetail / summary)

    func testDayDetailPropagatesFlatCoordinates() throws {
        let flat: [Double] = [52.5, 13.4, 52.51, 13.41]
        let export = makeExport(days: [
            Day(date: "2026-05-08", visits: [], activities: [], paths: [makeFlatPath(flat: flat)])
        ])
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-05-08", in: export))
        let pathItem = try XCTUnwrap(detail.paths.first)

        XCTAssertTrue(pathItem.points.isEmpty,
                      "Flat-only path must produce a PathItem with no points")
        XCTAssertEqual(pathItem.flatCoordinates, flat,
                       "Flat geometry must round-trip through dayDetail untouched")
    }

    func testDayDetailPointCountFromFlat() throws {
        // 3 vertices → flat count = 6 doubles.
        let flat: [Double] = [0, 0, 1, 1, 2, 2]
        let export = makeExport(days: [
            Day(date: "2026-05-08", visits: [], activities: [], paths: [makeFlatPath(flat: flat)])
        ])
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-05-08", in: export))
        let pathItem = try XCTUnwrap(detail.paths.first)

        XCTAssertEqual(pathItem.pointCount, 3,
                       "pointCount must equal flat.count / 2 when points are empty")
    }

    func testDayDetailDoesNotReportZeroDistanceForFlatOnlyPath() throws {
        // Two Berlin landmarks ~1.8 km apart.
        let flat: [Double] = [52.5200, 13.4050, 52.5163, 13.3777]
        let export = makeExport(days: [
            Day(date: "2026-05-08", visits: [], activities: [], paths: [makeFlatPath(flat: flat)])
        ])
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-05-08", in: export))
        let pathItem = try XCTUnwrap(detail.paths.first)

        XCTAssertGreaterThan(pathItem.effectiveDistanceM, 0,
                             "Flat-only paths must reconstruct distance from geometry")
    }

    func testSummaryTotalPathPointCountIncludesFlatVertices() throws {
        // Flat path has 4 vertices (8 doubles); points-path has 3 vertices.
        let flat: [Double] = [0, 0, 1, 1, 2, 2, 3, 3]
        let pointsPath = Path(
            startTime: nil, endTime: nil, activityType: "WALKING",
            distanceM: nil, sourceType: nil,
            points: [
                PathPoint(lat: 10, lon: 10, time: nil, accuracyM: nil),
                PathPoint(lat: 11, lon: 11, time: nil, accuracyM: nil),
                PathPoint(lat: 12, lon: 12, time: nil, accuracyM: nil)
            ],
            flatCoordinates: nil
        )
        let export = makeExport(days: [
            Day(
                date: "2026-05-08",
                visits: [], activities: [],
                paths: [makeFlatPath(flat: flat), pointsPath]
            )
        ])
        let summaries = AppExportQueries.daySummaries(from: export)
        let summary = try XCTUnwrap(summaries.first)

        XCTAssertEqual(summary.totalPathPointCount, 7,
                       "Summary must count 4 flat vertices + 3 points = 7 total")
    }

    func testEffectiveDistanceForFlatOnlyDayMatchesDetail() throws {
        let flat: [Double] = [52.5200, 13.4050, 52.5163, 13.3777, 52.5096, 13.3760]
        let export = makeExport(days: [
            Day(date: "2026-05-08", visits: [], activities: [], paths: [makeFlatPath(flat: flat)])
        ])

        let summary = try XCTUnwrap(AppExportQueries.daySummaries(from: export).first)
        let detail = try XCTUnwrap(AppExportQueries.dayDetail(for: "2026-05-08", in: export))
        let detailTotal = detail.paths.reduce(0.0) { $0 + $1.effectiveDistanceM }

        XCTAssertGreaterThan(summary.totalPathDistanceM, 0,
                             "Flat-only day must produce a non-zero total distance")
        XCTAssertEqual(summary.totalPathDistanceM, detailTotal, accuracy: 0.001,
                       "Summary and Day-detail must agree for flat-shaped paths too")
    }

    // MARK: - 3. PathDistanceCalculator (PathItem wrapper, flat branch)

    func testEffectiveDistanceForPathItemUsesFlatWhenPointsEmpty() {
        // Flat carries two Berlin landmarks ~1.8 km apart.
        let pathItem = DayDetailViewState.PathItem(
            startTime: nil, endTime: nil, activityType: nil,
            distanceM: nil, effectiveDistanceM: 0,
            pointCount: 2, sourceType: "google_timeline",
            points: [],
            flatCoordinates: [52.5200, 13.4050, 52.5163, 13.3777]
        )
        let result = PathDistanceCalculator.effectiveDistance(for: pathItem)
        XCTAssertGreaterThan(result, 1500)
        XCTAssertLessThan(result, 3000)
    }

    func testEffectiveDistanceForPathItemPointsTakePrecedence() {
        // Points are nearly identical (~few cm); flat would imply ~10000 km
        // if it were used. Verifies the legacy-points-take-precedence rule.
        let pathItem = DayDetailViewState.PathItem(
            startTime: nil, endTime: nil, activityType: nil,
            distanceM: nil, effectiveDistanceM: 0,
            pointCount: 2, sourceType: nil,
            points: [
                DayDetailViewState.PathPointItem(lat: 52.52, lon: 13.40, time: nil, accuracyM: nil),
                DayDetailViewState.PathPointItem(lat: 52.52, lon: 13.40, time: nil, accuracyM: nil)
            ],
            flatCoordinates: [0, 0, 0, 90] // would be ~10_000 km if used
        )
        let result = PathDistanceCalculator.effectiveDistance(for: pathItem)
        XCTAssertLessThan(result, 1.0,
                          "Points must take precedence — flat must be ignored when points has ≥ 2")
    }

    // MARK: - 4. DayMapDataExtractor

    func testMapDataExtractsFromFlatOnlyPath() {
        let detail = makeDetail(paths: [
            DayDetailViewState.PathItem(
                startTime: nil, endTime: nil, activityType: "WALKING",
                distanceM: nil, effectiveDistanceM: 100,
                pointCount: 2, sourceType: nil,
                points: [],
                flatCoordinates: [0, 0, 1, 1]
            )
        ])
        let mapData = DayMapDataExtractor.mapData(from: detail)

        XCTAssertEqual(mapData.pathOverlays.count, 1)
        let overlay = mapData.pathOverlays[0]
        XCTAssertEqual(overlay.coordinates.count, 2)
        XCTAssertEqual(overlay.coordinates[0], DayMapCoordinate(lat: 0, lon: 0))
        XCTAssertEqual(overlay.coordinates[1], DayMapCoordinate(lat: 1, lon: 1))
        XCTAssertTrue(overlay.timestamps.isEmpty,
                      "Flat geometry has no per-point times — Tempolayer must fall back")
    }

    func testMapDataPrefersPointsOverFlat() {
        // Points populated AND flat populated — the points shape wins.
        let detail = makeDetail(paths: [
            DayDetailViewState.PathItem(
                startTime: nil, endTime: nil, activityType: "WALKING",
                distanceM: nil, effectiveDistanceM: 0,
                pointCount: 2, sourceType: nil,
                points: [
                    DayDetailViewState.PathPointItem(lat: 10, lon: 20, time: "T1", accuracyM: nil),
                    DayDetailViewState.PathPointItem(lat: 11, lon: 21, time: "T2", accuracyM: nil)
                ],
                flatCoordinates: [99, 99, 88, 88]
            )
        ])
        let mapData = DayMapDataExtractor.mapData(from: detail)
        let overlay = mapData.pathOverlays.first

        XCTAssertEqual(overlay?.coordinates, [
            DayMapCoordinate(lat: 10, lon: 20),
            DayMapCoordinate(lat: 11, lon: 21)
        ], "Points must win over flatCoordinates for legacy compat")
        XCTAssertEqual(overlay?.timestamps, ["T1", "T2"],
                       "Per-point timestamps must come from points, not flat")
    }

    func testMapDataIgnoresOddFlat() {
        let detail = makeDetail(paths: [
            DayDetailViewState.PathItem(
                startTime: nil, endTime: nil, activityType: nil,
                distanceM: nil, effectiveDistanceM: 0,
                pointCount: 0, sourceType: nil,
                points: [],
                flatCoordinates: [0, 0, 1] // odd → malformed
            )
        ])
        let mapData = DayMapDataExtractor.mapData(from: detail)
        XCTAssertTrue(mapData.pathOverlays.isEmpty,
                      "Odd-count flatCoordinates must produce no overlay")
    }

    // MARK: - 5. GPX / KML / GeoJSON / CSV builders

    func testGPXEmitsTrkptsFromFlat() {
        let day = Day(
            date: "2026-05-08",
            visits: [], activities: [],
            paths: [makeFlatPath(flat: [47.0, 8.0, 47.001, 8.001])]
        )
        let gpx = GPXBuilder.build(from: [day])

        XCTAssertTrue(gpx.contains("<trk>"))
        // Expect two trkpt entries — and crucially they must be self-closing
        // (no `<time>` element) because flat has no per-point timestamps.
        let trkptCount = gpx.components(separatedBy: "<trkpt ").count - 1
        XCTAssertEqual(trkptCount, 2, "Two flat vertices must produce two trkpt entries")
        XCTAssertTrue(gpx.contains(#"lat="47.00000000""#))
        XCTAssertTrue(gpx.contains(#"lat="47.00100000""#))
        XCTAssertTrue(gpx.contains(#"lon="8.00000000""#))
        XCTAssertFalse(gpx.contains("<time>"),
                       "Flat geometry has no per-point times; <time> must be absent")
    }

    func testKMLEmitsCoordinatesFromFlat() {
        let day = Day(
            date: "2026-05-08",
            visits: [], activities: [],
            paths: [makeFlatPath(flat: [47.0, 8.0, 47.001, 8.001])]
        )
        let kml = KMLBuilder.build(from: [day])

        XCTAssertTrue(kml.contains("<LineString>"))
        // KML coordinates are lon,lat — flat is lat,lon so they swap.
        XCTAssertTrue(kml.contains("8.00000000,47.00000000"))
        XCTAssertTrue(kml.contains("8.00100000,47.00100000"))
    }

    func testGeoJSONEmitsLineStringFromFlat() throws {
        let day = Day(
            date: "2026-05-08",
            visits: [], activities: [],
            paths: [makeFlatPath(flat: [47.0, 8.0, 47.001, 8.001])]
        )
        let geoJSON = try GeoJSONBuilder.build(from: [day])
        let data = try XCTUnwrap(geoJSON.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let features = try XCTUnwrap(parsed["features"] as? [[String: Any]])
        XCTAssertEqual(features.count, 1)
        let geometry = try XCTUnwrap(features[0]["geometry"] as? [String: Any])
        XCTAssertEqual(geometry["type"] as? String, "LineString")
        let coordinates = try XCTUnwrap(geometry["coordinates"] as? [[Double]])
        XCTAssertEqual(coordinates.count, 2)
        // GeoJSON coordinates are [lon, lat].
        XCTAssertEqual(coordinates[0], [8.0, 47.0])
        XCTAssertEqual(coordinates[1], [8.001, 47.001])
    }

    func testCSVRouteRowFromFlat() throws {
        let flat: [Double] = [47.0, 8.0, 47.5, 8.5, 48.0, 9.0]
        let day = Day(
            date: "2026-05-08",
            visits: [], activities: [],
            paths: [makeFlatPath(flat: flat)]
        )
        let csv = CSVBuilder.build(from: [day])
        let dataLines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Header + one route row.
        XCTAssertEqual(dataLines.count, 2)

        // Look up column indices by name from the canonical header so the
        // test stays robust against future column reorderings.
        let header = dataLines[0].components(separatedBy: ",")
        let row = dataLines[1].components(separatedBy: ",")
        XCTAssertEqual(row.count, header.count, "Row must match header column count")

        func col(_ name: String) throws -> String {
            let idx = try XCTUnwrap(header.firstIndex(of: name), "Missing CSV column \(name)")
            return row[idx]
        }

        XCTAssertEqual(try col("entryType"), "route")
        XCTAssertEqual(try col("pointCount"), "3", "pointCount must equal flat.count / 2")
        XCTAssertEqual(try col("startLat"), "47.000000")
        XCTAssertEqual(try col("startLon"), "8.000000")
        XCTAssertEqual(try col("endLat"), "48.000000")
        XCTAssertEqual(try col("endLon"), "9.000000")
    }

    // MARK: - 6. GoogleTimelineConverter (integration)

    func testConverterProducesFlatGeometry() throws {
        let json = """
        [
            {
                "startTime": "2026-05-08T10:00:00Z",
                "endTime": "2026-05-08T10:30:00Z",
                "timelinePath": [
                    { "point": "geo:52.52,13.40", "durationMinutesOffsetFromStartTime": "0" },
                    { "point": "geo:52.53,13.41", "durationMinutesOffsetFromStartTime": "10" },
                    { "point": "geo:52.54,13.42", "durationMinutesOffsetFromStartTime": "20" }
                ]
            }
        ]
        """
        let export = try GoogleTimelineConverter.convert(data: Data(json.utf8))
        let day = try XCTUnwrap(export.data.days.first)
        let path = try XCTUnwrap(day.paths.first)

        XCTAssertTrue(path.points.isEmpty,
                      "Converter must emit empty points array — flat is canonical")
        let flat = try XCTUnwrap(path.flatCoordinates)
        XCTAssertEqual(flat.count, 6, "3 vertices × 2 doubles each = 6")
        XCTAssertEqual(flat[0], 52.52)
        XCTAssertEqual(flat[1], 13.40)
        XCTAssertEqual(flat[2], 52.53)
        XCTAssertEqual(flat[3], 13.41)
        XCTAssertEqual(flat[4], 52.54)
        XCTAssertEqual(flat[5], 13.42)
    }

    func testConverterPathHasNoTimestamps() throws {
        let json = """
        [
            {
                "startTime": "2026-05-08T10:00:00Z",
                "endTime": "2026-05-08T10:30:00Z",
                "timelinePath": [
                    { "point": "geo:52.52,13.40", "durationMinutesOffsetFromStartTime": "0" },
                    { "point": "geo:52.53,13.41", "durationMinutesOffsetFromStartTime": "15" }
                ]
            }
        ]
        """
        let export = try GoogleTimelineConverter.convert(data: Data(json.utf8))
        let path = try XCTUnwrap(export.data.days.first?.paths.first)

        // Per-point timestamps were dropped to kill the post-stream memory
        // peak. Path-level start/endTime stay (they're cheap, one per path).
        XCTAssertTrue(path.points.isEmpty,
                      "No PathPoint entries means no per-point ISO time strings")
        XCTAssertEqual(path.startTime, "2026-05-08T10:00:00Z",
                       "Path-level startTime must still be preserved")
        XCTAssertEqual(path.endTime, "2026-05-08T10:30:00Z",
                       "Path-level endTime must still be preserved")
    }

    // MARK: - 7. AppHeatmapModel doppel-bug regression

    #if canImport(MapKit)
    /// Regression coverage for the AppHeatmapModel doppel-bug: when a path
    /// has BOTH `points` and `flatCoordinates` populated, density must read
    /// only ONE of them (points wins). Before the fix every vertex was
    /// counted twice — once via points, once via flat — inflating heatmap
    /// intensity in the bridge case.
    ///
    /// AppHeatmapModel populates `stats.totalPoints` only after the detached
    /// `startPrecomputation` task completes. We poll on the @MainActor with
    /// a short timeout. Skips on Linux because MapKit is unavailable.
    @MainActor
    func testHeatmapDoesNotDoubleCountPointsAndFlatPath() async throws {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            throw XCTSkip("AppHeatmapModel requires iOS 17 / macOS 14")
        }
        // Path has 2 points AND 2 flat vertices. Without the doppel-fix
        // density would total 4. After the fix it must total 2 (points wins).
        let day = Day(
            date: "2026-05-08",
            visits: [],
            activities: [],
            paths: [
                Path(
                    startTime: nil, endTime: nil, activityType: "WALKING",
                    distanceM: nil, sourceType: nil,
                    points: [
                        PathPoint(lat: 52.5, lon: 13.4, time: nil, accuracyM: nil),
                        PathPoint(lat: 52.51, lon: 13.41, time: nil, accuracyM: nil)
                    ],
                    flatCoordinates: [0, 0, 1, 1]
                )
            ]
        )
        let export = makeExport(days: [day])
        let model = AppHeatmapModel(export: export)
        model.startPrecomputation(scale: .logarithmic)

        // The detached precomputation hops back to MainActor to populate
        // `stats`. Poll a few times — bounded so a wedged test fails fast.
        let deadline = Date().addingTimeInterval(5)
        while model.stats.totalPoints == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(model.stats.totalPoints, 2,
                       "Path with both points (2) and flat (2) populated must contribute exactly 2 — not 4 — to density")
    }
    #endif

    // MARK: - Helpers

    private func makeFlatPath(flat: [Double]?) -> Path {
        Path(
            startTime: nil,
            endTime: nil,
            activityType: nil,
            distanceM: nil,
            sourceType: "google_timeline",
            points: [],
            flatCoordinates: flat
        )
    }

    private func makeDetail(paths: [DayDetailViewState.PathItem]) -> DayDetailViewState {
        DayDetailViewState(
            date: "2026-05-08",
            visits: [],
            activities: [],
            paths: paths,
            totalPathPointCount: paths.reduce(0) { $0 + $1.pointCount },
            hasContent: !paths.isEmpty
        )
    }

    private func makeExport(days: [Day]) -> AppExport {
        AppExport(
            schemaVersion: .v1_0,
            meta: Meta(
                exportedAt: "2026-05-08T00:00:00Z",
                toolVersion: "test/1.0",
                source: Source(zipBasename: nil, zipPath: nil, inputFormat: "google_timeline"),
                output: Output(outDir: nil),
                config: ExportConfig(
                    mode: nil,
                    splitMidnight: nil,
                    splitMode: nil,
                    exportFormat: nil,
                    inputFormat: "google_timeline"
                ),
                filters: ExportFilters(
                    fromDate: nil, toDate: nil, year: nil, month: nil,
                    weekday: nil, limit: nil, days: nil, has: nil,
                    maxAccuracyM: nil, activityTypes: nil, minGapMin: nil
                )
            ),
            data: DataBlock(days: days),
            stats: nil
        )
    }
}
