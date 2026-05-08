import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-5 — Validates the value-only Export-Zielmodell (Format / Selection /
/// Result / Error). No I/O, no store access; pure data shape.
final class LocalTimelineExportSelectionTests: XCTestCase {

    func testFormatFileExtensions() {
        XCTAssertEqual(LocalTimelineExportFormat.gpx.fileExtension, "gpx")
        XCTAssertEqual(LocalTimelineExportFormat.kml.fileExtension, "kml")
        XCTAssertEqual(LocalTimelineExportFormat.geoJSON.fileExtension, "geojson")
        XCTAssertEqual(LocalTimelineExportFormat.csv.fileExtension, "csv")
    }

    func testFormatAllCasesContainsAllFour() {
        XCTAssertEqual(Set(LocalTimelineExportFormat.allCases),
                       Set([.gpx, .kml, .geoJSON, .csv]))
    }

    func testSelectionDefaultsIncludeEverything() {
        let s = LocalTimelineExportSelection(importID: "imp-1")
        XCTAssertTrue(s.includeVisits)
        XCTAssertTrue(s.includeActivities)
        XCTAssertTrue(s.includePaths)
        XCTAssertNil(s.dateRange)
        XCTAssertNil(s.dayIds)
    }

    func testSelectionCarriesFiltersAndIDs() {
        let s = LocalTimelineExportSelection(
            importID: "imp-1",
            dateRange: "2024-01-01"..."2024-01-03",
            dayIds: ["d1", "d2"],
            includeVisits: false,
            includeActivities: true,
            includePaths: true)
        XCTAssertEqual(s.importID, "imp-1")
        XCTAssertEqual(s.dateRange, "2024-01-01"..."2024-01-03")
        XCTAssertEqual(s.dayIds, ["d1", "d2"])
        XCTAssertFalse(s.includeVisits)
    }

    func testResultEqualityIsFieldwise() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let a = LocalTimelineExportResult(outputURL: url, format: .gpx,
                                          bytesWritten: 12, dayCount: 1,
                                          pathCount: 2, visitCount: 3,
                                          activityCount: 4, pointCount: 5)
        let b = LocalTimelineExportResult(outputURL: url, format: .gpx,
                                          bytesWritten: 12, dayCount: 1,
                                          pathCount: 2, visitCount: 3,
                                          activityCount: 4, pointCount: 5)
        XCTAssertEqual(a, b)
    }

    func testErrorDescriptionsAreDiagnostic() {
        XCTAssertTrue("\(LocalTimelineExportError.unknownImport(importID: "xx"))".contains("xx"))
        XCTAssertTrue("\(LocalTimelineExportError.emptySelection(importID: "yy"))".contains("yy"))
        XCTAssertTrue("\(LocalTimelineExportError.malformedCoordBlob(pathID: "p1", message: "boom"))".contains("p1"))
    }
}
