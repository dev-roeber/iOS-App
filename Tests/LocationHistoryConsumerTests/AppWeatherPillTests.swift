import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class AppWeatherPillTests: XCTestCase {

    func testNilSnapshotInstantiates() {
        let pill = AppWeatherPill(snapshot: nil)
        _ = pill.body
    }

    func testSnapshotInstantiates() {
        let snap = WeatherSnapshot(temperatureC: 21.4, condition: "Sonnig", timestamp: Date())
        let pill = AppWeatherPill(snapshot: snap)
        _ = pill.body
    }

    func testErrorInstantiates() {
        let pill = AppWeatherPill(snapshot: nil, isError: true, errorLabel: "Wetter unverfügbar")
        _ = pill.body
    }

    func testTapCallback() {
        var tapped = false
        let pill = AppWeatherPill(snapshot: nil, isError: true, onTap: { tapped = true })
        _ = pill.body
        // We can't simulate the SwiftUI press in this unit harness, but the
        // closure capture must compile + retain.
        XCTAssertFalse(tapped)
        _ = tapped
    }

    func testTemperatureFormatting() {
        XCTAssertEqual(AppWeatherPill.formatTemperature(20.4), "20°")
        XCTAssertEqual(AppWeatherPill.formatTemperature(20.6), "21°")
        XCTAssertEqual(AppWeatherPill.formatTemperature(-0.4), "0°")
    }

    func testConditionShortening() {
        XCTAssertEqual(AppWeatherPill.shorten("Sonnig"), "Sonnig")
        XCTAssertTrue(AppWeatherPill.shorten("Stark bewölkt mit Regen").count <= 14)
    }

    func testSymbolMapping() {
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Sonnig"), "sun.max.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Clear"), "sun.max.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Regen"), "cloud.rain.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Schnee"), "cloud.snow.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Gewitter"), "cloud.bolt.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Nebel"), "cloud.fog.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Teilweise bewölkt"), "cloud.sun.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "Bewölkt"), "cloud.fill")
        XCTAssertEqual(AppWeatherPill.symbolName(for: "unknown"), "cloud.fill")
    }
}
#endif
