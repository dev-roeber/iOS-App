import XCTest
@testable import LocationHistoryConsumer

/// Train-A baseline (2026-05-16): Foundation-only, Linux-CI-portable
/// throughput probes for the four pure-string export builders:
///
/// - `GPXBuilder.build(from:additionalTracks:mode:)`
/// - `KMLBuilder.build(from:mode:)`
/// - `CSVBuilder.build(from:)`
/// - `GeoJSONBuilder.build(from:mode:)`
///
/// KMZ is **not** included here: `KMZBuilder` zips a KML payload via
/// ZIPFoundation; its hot path is the ZIP archive emitter, not the KML
/// string. KML throughput is the relevant baseline for both.
///
/// Inputs are deterministic 3-day exports with 1×5 000-point or 3×1 666-
/// point tracks, plus a handful of visits — well within the realistic
/// "user accepts an export" envelope. `measure { … }` reports mean +
/// standard deviation, **no fail-bar** so CI does not flake on host
/// wall-clock drift. Assertions stay minimal so the runtime stays inside
/// the measured closure.
final class ExportBuildersPerformanceTests: XCTestCase {

    private static let smallExport: [Day] = synthesizeExport(
        dayCount: 1,
        pointsPerTrack: 1_000,
        visitsPerDay: 5
    )
    private static let largeExport: [Day] = synthesizeExport(
        dayCount: 3,
        pointsPerTrack: 5_000,
        visitsPerDay: 10
    )

    // MARK: - GPX

    func testGPXBuild1kPoints() {
        let days = Self.smallExport
        measure {
            let gpx = GPXBuilder.build(from: days)
            XCTAssertFalse(gpx.isEmpty)
        }
    }

    func testGPXBuild5kPointsAcross3Days() {
        let days = Self.largeExport
        measure {
            let gpx = GPXBuilder.build(from: days)
            XCTAssertFalse(gpx.isEmpty)
        }
    }

    // MARK: - KML

    func testKMLBuild1kPoints() {
        let days = Self.smallExport
        measure {
            let kml = KMLBuilder.build(from: days)
            XCTAssertFalse(kml.isEmpty)
        }
    }

    func testKMLBuild5kPointsAcross3Days() {
        let days = Self.largeExport
        measure {
            let kml = KMLBuilder.build(from: days)
            XCTAssertFalse(kml.isEmpty)
        }
    }

    // MARK: - CSV

    func testCSVBuild1kPoints() {
        let days = Self.smallExport
        measure {
            let csv = CSVBuilder.build(from: days)
            XCTAssertFalse(csv.isEmpty)
        }
    }

    func testCSVBuild5kPointsAcross3Days() {
        let days = Self.largeExport
        measure {
            let csv = CSVBuilder.build(from: days)
            XCTAssertFalse(csv.isEmpty)
        }
    }

    // MARK: - GeoJSON

    func testGeoJSONBuild1kPoints() throws {
        let days = Self.smallExport
        var lastError: Error?
        measure {
            do {
                let geojson = try GeoJSONBuilder.build(from: days)
                XCTAssertFalse(geojson.isEmpty)
            } catch {
                lastError = error
            }
        }
        if let lastError {
            XCTFail("GeoJSON build threw: \(lastError)")
        }
    }

    func testGeoJSONBuild5kPointsAcross3Days() throws {
        let days = Self.largeExport
        var lastError: Error?
        measure {
            do {
                let geojson = try GeoJSONBuilder.build(from: days)
                XCTAssertFalse(geojson.isEmpty)
            } catch {
                lastError = error
            }
        }
        if let lastError {
            XCTFail("GeoJSON build threw: \(lastError)")
        }
    }

    // MARK: - Structural sanity (output content) — keep these cheap and
    //         outside `measure { … }` so we are not timing the assertions.

    func testGPXBuildContainsExpectedStructure() {
        let gpx = GPXBuilder.build(from: Self.smallExport)
        XCTAssertTrue(gpx.contains("<?xml"))
        XCTAssertTrue(gpx.contains("<gpx"))
        XCTAssertTrue(gpx.contains("<trk>"))
        XCTAssertTrue(gpx.contains("</gpx>"))
    }

    func testKMLBuildContainsExpectedStructure() {
        let kml = KMLBuilder.build(from: Self.smallExport)
        XCTAssertTrue(kml.contains("<?xml"))
        XCTAssertTrue(kml.contains("<kml"))
        XCTAssertTrue(kml.contains("</kml>"))
    }

    func testCSVBuildContainsHeader() {
        let csv = CSVBuilder.build(from: Self.smallExport)
        XCTAssertFalse(csv.isEmpty)
        XCTAssertTrue(csv.contains(","))
    }

    func testGeoJSONBuildIsParseableJSON() throws {
        let geojson = try GeoJSONBuilder.build(from: Self.smallExport)
        let data = Data(geojson.utf8)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    // MARK: - Helpers

    /// Deterministic synthetic export.
    /// - Parameter dayCount: One Day entry per element.
    /// - Parameter pointsPerTrack: Total points spread across the single
    ///   track in that day. A `1e-5` lat/lon stride keeps the bounding box
    ///   tight without producing identical points.
    /// - Parameter visitsPerDay: How many `Visit` entries to attach.
    private static func synthesizeExport(
        dayCount: Int,
        pointsPerTrack: Int,
        visitsPerDay: Int
    ) -> [Day] {
        var days: [Day] = []
        days.reserveCapacity(dayCount)
        for dayIdx in 0..<dayCount {
            let date = String(format: "2024-01-%02d", dayIdx + 1)
            var points: [PathPoint] = []
            points.reserveCapacity(pointsPerTrack)
            for i in 0..<pointsPerTrack {
                let lat = 50.0 + Double(i % 5_000) * 1e-5
                let lon = 8.0 + Double(i % 5_000) * 1e-5
                let time = String(
                    format: "%@T%02d:%02d:%02dZ",
                    date,
                    (i / 3600) % 24,
                    (i / 60) % 60,
                    i % 60
                )
                points.append(PathPoint(lat: lat, lon: lon, time: time, accuracyM: 10))
            }
            let path = Path(
                startTime: "\(date)T00:00:00Z",
                endTime: "\(date)T23:59:59Z",
                activityType: "WALKING",
                distanceM: nil,
                sourceType: nil,
                points: points,
                flatCoordinates: nil
            )
            var visits: [Visit] = []
            visits.reserveCapacity(visitsPerDay)
            for v in 0..<visitsPerDay {
                visits.append(Visit(
                    lat: 50.0 + Double(v) * 1e-3,
                    lon: 8.0 + Double(v) * 1e-3,
                    startTime: "\(date)T0\(v % 10):00:00Z",
                    endTime: "\(date)T0\(v % 10):30:00Z",
                    semanticType: "HOME",
                    placeID: "perf-\(dayIdx)-\(v)",
                    accuracyM: 15,
                    sourceType: nil
                ))
            }
            days.append(Day(date: date, visits: visits, activities: [], paths: [path]))
        }
        return days
    }
}
