import XCTest
@testable import LocationHistoryConsumer
@testable import LocationHistoryConsumerAppSupport

final class ExportFormatGuidancePresentationTests: XCTestCase {

    func testTitleReflectsFormatRawValueInBothLanguages() {
        XCTAssertEqual(ExportFormatGuidancePresentation.title(for: .gpx, german: false), "GPX guidance")
        XCTAssertEqual(ExportFormatGuidancePresentation.title(for: .gpx, german: true),  "GPX-Hilfe")
        XCTAssertEqual(ExportFormatGuidancePresentation.title(for: .kmz, german: false), "KMZ guidance")
        XCTAssertEqual(ExportFormatGuidancePresentation.title(for: .csv, german: true),  "CSV-Hilfe")
    }

    func testToolsLineCarriesLocalisedPrefix() {
        XCTAssertTrue(ExportFormatGuidancePresentation.toolsLine(typicalTools: "X, Y", german: false)
            .hasPrefix("Typical tools: "))
        XCTAssertTrue(ExportFormatGuidancePresentation.toolsLine(typicalTools: "X, Y", german: true)
            .hasPrefix("Typische Tools: "))
    }

    func testRenderedStrengthBulletsAreBulletPrefixed() {
        for format in ExportFormat.allCases {
            let rendered = ExportFormatGuidancePresentation.rendered(for: format, german: false)
            XCTAssertFalse(rendered.strengths.isEmpty)
            for bullet in rendered.strengths {
                XCTAssertTrue(bullet.hasPrefix("• "), "Strength bullet for \(format) must start with '• '.")
            }
        }
    }

    func testRenderedTitleAndPrimaryUseAreNeverEmpty() {
        for format in ExportFormat.allCases {
            for german in [false, true] {
                let r = ExportFormatGuidancePresentation.rendered(for: format, german: german)
                XCTAssertFalse(r.title.isEmpty)
                XCTAssertFalse(r.primaryUse.isEmpty)
                XCTAssertFalse(r.tools.isEmpty)
            }
        }
    }

    func testRenderedPrimaryUseDiffersBetweenLanguages() {
        for format in ExportFormat.allCases {
            let en = ExportFormatGuidancePresentation.rendered(for: format, german: false)
            let de = ExportFormatGuidancePresentation.rendered(for: format, german: true)
            XCTAssertNotEqual(en.primaryUse, de.primaryUse, "\(format) primary use must differ.")
            XCTAssertNotEqual(en.title, de.title, "\(format) title must differ.")
        }
    }

    func testRenderedContainsNoCoordinatesOrPlaceIDs() {
        let pattern = #"\b\d{1,3}\.\d{3,}\b"#
        for format in ExportFormat.allCases {
            for german in [false, true] {
                let r = ExportFormatGuidancePresentation.rendered(for: format, german: german)
                let blob = ([r.title, r.primaryUse, r.tools] + r.strengths).joined(separator: " ")
                XCTAssertNil(blob.range(of: pattern, options: .regularExpression))
                XCTAssertFalse(blob.contains("place_id"))
            }
        }
    }
}
