import XCTest
@testable import LocationHistoryConsumerAppSupport

#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class AppElevationProfileViewTests: XCTestCase {

    func testInstantiatesWithPoints() {
        let points = (0..<10).map {
            AppElevationProfileSample(distance: Double($0) * 100, elevation: 200 + Double($0))
        }
        let view = AppElevationProfileView(points: points)
        XCTAssertFalse(view.debug_isExpanded)
        XCTAssertEqual(view.debug_pointCount, 10)
        XCTAssertEqual(view.debug_elevationBounds?.lo, 200)
        XCTAssertEqual(view.debug_elevationBounds?.hi, 209)
    }

    func testMinMaxToggleViaInitialState() {
        let points = [
            AppElevationProfileSample(distance: 0, elevation: 100),
            AppElevationProfileSample(distance: 50, elevation: 150)
        ]
        XCTAssertFalse(AppElevationProfileView(points: points).debug_isExpanded)
        XCTAssertTrue(AppElevationProfileView(points: points, initiallyExpanded: true).debug_isExpanded)
    }

    func testEmptyPointsState() {
        let view = AppElevationProfileView(points: [])
        XCTAssertEqual(view.debug_pointCount, 0)
        XCTAssertNil(view.debug_elevationBounds)
    }

    func testCompactAndExpandedHeightsAreDistinct() {
        XCTAssertLessThan(AppElevationProfileView.compactHeight, AppElevationProfileView.expandedHeight)
    }
}
#endif
