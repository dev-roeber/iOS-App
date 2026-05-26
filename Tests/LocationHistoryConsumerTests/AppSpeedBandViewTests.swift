import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class AppSpeedBandViewTests: XCTestCase {

    func testInstantiatesWithSamples() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0..<8).map {
            AppSpeedBandSample(timestamp: now.addingTimeInterval(Double($0) * 10), speed: Double($0))
        }
        let view = AppSpeedBandView(speeds: samples)
        XCTAssertFalse(view.debug_isExpanded)
        XCTAssertEqual(view.debug_speedRange.lowerBound, 0)
        XCTAssertEqual(view.debug_speedRange.upperBound, 7)
    }

    func testInitiallyExpandedTogglesState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = [
            AppSpeedBandSample(timestamp: now, speed: 1.5),
            AppSpeedBandSample(timestamp: now.addingTimeInterval(60), speed: 4.2)
        ]
        let compact = AppSpeedBandView(speeds: samples, initiallyExpanded: false)
        let expanded = AppSpeedBandView(speeds: samples, initiallyExpanded: true)
        XCTAssertFalse(compact.debug_isExpanded)
        XCTAssertTrue(expanded.debug_isExpanded)
    }

    func testEmptySpeedsCollapseToPlaceholderRange() {
        let view = AppSpeedBandView(speeds: [])
        // Empty input still hands back a stable default range (0...1) so the
        // chart never divides by zero.
        XCTAssertEqual(view.debug_speedRange.lowerBound, 0)
        XCTAssertEqual(view.debug_speedRange.upperBound, 1)
    }

    func testCompactAndExpandedHeightsAreDistinct() {
        XCTAssertLessThan(AppSpeedBandView.compactHeight, AppSpeedBandView.expandedHeight)
    }
}
#endif
