import XCTest
@testable import LocationHistoryConsumerAppSupport
@testable import LocationHistoryConsumer

final class ExportFormatGuidanceTests: XCTestCase {

    func testEveryFormatHasNonEmptyEnglishCopy() {
        for format in ExportFormat.allCases {
            let copy = ExportFormatGuidance.copy(for: format, german: false)
            XCTAssertFalse(copy.primaryUseCase.isEmpty, "\(format) EN primary use case is empty.")
            XCTAssertFalse(copy.typicalTools.isEmpty, "\(format) EN typical tools is empty.")
            XCTAssertGreaterThanOrEqual(copy.strengths.count, 2,
                                        "\(format) EN strengths should list at least two bullets.")
            for bullet in copy.strengths {
                XCTAssertFalse(bullet.isEmpty, "\(format) EN strength bullet must not be empty.")
            }
        }
    }

    func testEveryFormatHasNonEmptyGermanCopy() {
        for format in ExportFormat.allCases {
            let copy = ExportFormatGuidance.copy(for: format, german: true)
            XCTAssertFalse(copy.primaryUseCase.isEmpty, "\(format) DE primary use case is empty.")
            XCTAssertFalse(copy.typicalTools.isEmpty, "\(format) DE typical tools is empty.")
            XCTAssertGreaterThanOrEqual(copy.strengths.count, 2,
                                        "\(format) DE strengths should list at least two bullets.")
        }
    }

    func testEnglishAndGermanDifferForEveryFormat() {
        for format in ExportFormat.allCases {
            let en = ExportFormatGuidance.copy(for: format, german: false)
            let de = ExportFormatGuidance.copy(for: format, german: true)
            XCTAssertNotEqual(en.primaryUseCase, de.primaryUseCase,
                              "\(format): EN and DE primary use case must not be identical.")
        }
    }

    func testGpxCopyMentionsNavigationKeyword() {
        let en = ExportFormatGuidance.copy(for: .gpx, german: false)
        XCTAssertTrue(en.primaryUseCase.lowercased().contains("navigation")
                      || en.primaryUseCase.lowercased().contains("route"),
                      "GPX EN copy should reference navigation/route context.")
    }

    func testCsvCopyMentionsSpreadsheetKeyword() {
        let en = ExportFormatGuidance.copy(for: .csv, german: false)
        XCTAssertTrue(en.primaryUseCase.lowercased().contains("spreadsheet")
                      || en.primaryUseCase.lowercased().contains("tabular"),
                      "CSV EN copy should reference spreadsheets/tabular use.")
    }

    func testGeoJSONCopyMentionsGISOrWebKeyword() {
        let en = ExportFormatGuidance.copy(for: .geoJSON, german: false)
        let lower = en.primaryUseCase.lowercased() + " " + en.typicalTools.lowercased()
        XCTAssertTrue(lower.contains("gis") || lower.contains("web") || lower.contains("qgis"),
                      "GeoJSON EN copy should reference GIS/Web/QGIS context.")
    }

    /// Copy must never embed live data — these are static helper strings.
    func testCopyContainsNoNumericCoordinatesOrPlaceIDs() {
        for format in ExportFormat.allCases {
            for german in [false, true] {
                let copy = ExportFormatGuidance.copy(for: format, german: german)
                let joined = copy.primaryUseCase + " " + copy.typicalTools + " " + copy.strengths.joined(separator: " ")
                // No decimal coordinate-like fragments (e.g. "50.123" or "10.456").
                let coordinatePattern = #"\b\d{1,3}\.\d{3,}\b"#
                let range = joined.range(of: coordinatePattern, options: .regularExpression)
                XCTAssertNil(range,
                             "\(format) \(german ? "DE" : "EN") copy must not embed coordinate-like numbers.")
                XCTAssertFalse(joined.contains("place_id="),
                               "\(format) \(german ? "DE" : "EN") copy must not embed place IDs.")
            }
        }
    }
}
