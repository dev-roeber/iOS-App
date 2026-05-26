import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class AppWeatherAttributionViewTests: XCTestCase {

    func testDefaultInitializerInstantiates() {
        let view = AppWeatherAttributionView()
        _ = view.body
    }

    func testCustomLabelInstantiates() {
        let view = AppWeatherAttributionView(label: "Weather")
        _ = view.body
    }

    func testInvalidLegalURLStillRenders() {
        // Empty string is not a valid URL — view should fall back to plain Text.
        let view = AppWeatherAttributionView(label: "Wetter", legalURLString: "")
        _ = view.body
    }
}
#endif
