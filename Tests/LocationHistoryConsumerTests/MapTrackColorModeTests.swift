import XCTest
import LocationHistoryConsumerAppSupport

final class MapTrackColorModeTests: XCTestCase {
    func testLayerToggleModesExposeFourRenderingChoices() {
        XCTAssertEqual(
            AppMapTrackColorMode.allCases.map(\.rawValue),
            ["activity", "speed", "elevation", "weather"]
        )
    }

    func testLayerToggleModesRoundTripFromRawValues() {
        for mode in AppMapTrackColorMode.allCases {
            XCTAssertEqual(AppMapTrackColorMode(rawValue: mode.rawValue), mode)
        }
    }

    func testLayerToggleModeLabelsMatchPublicCases() {
        XCTAssertEqual(AppMapTrackColorMode.activity.labelKey, "Standard")
        XCTAssertEqual(AppMapTrackColorMode.speed.labelKey, "Speed")
        XCTAssertEqual(AppMapTrackColorMode.elevation.labelKey, "Elevation")
        XCTAssertEqual(AppMapTrackColorMode.weather.labelKey, "Weather")
    }
}
