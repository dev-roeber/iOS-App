#if canImport(SwiftUI)
import SwiftUI
import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LH2GPXThemeTests: XCTestCase {
    func testLiquidGlassSurfaceCompiles() {
        let view = LHLiquidGlassSurface {
            Text("x")
        }
        _ = view.body
    }

    func testLiquidGlassPrivacyPillCompiles() {
        let view = LHLiquidGlassPrivacyPill("Processed locally")
        _ = view.body
    }
}
#endif
