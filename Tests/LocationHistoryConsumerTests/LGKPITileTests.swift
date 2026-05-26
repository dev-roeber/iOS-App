#if canImport(SwiftUI)
import XCTest
import SwiftUI
@testable import LocationHistoryConsumerAppSupport

/// Smoke tests for `LGKPITile` (Spec §8). The runtime `precondition` on the
/// mandatory `label` parameter cannot be trapped from XCTest without an
/// `XCTExpectFailure`-style harness, so the negative case is left as a
/// debug-only assertion. These tests at least verify the happy-path
/// initializer compiles and stores its inputs verbatim — which catches
/// accidental field renames in the public initializer.
final class LGKPITileTests: XCTestCase {

    func testTileStoresValuesVerbatim() {
        let tile = LGKPITile(
            value: "12",
            label: "DAYS",
            icon: "calendar",
            tint: .blue
        )
        XCTAssertEqual(tile.value, "12")
        XCTAssertEqual(tile.label, "DAYS")
        XCTAssertEqual(tile.icon, "calendar")
        XCTAssertEqual(tile.tint, .blue)
    }

    func testTileBodyBuilds() {
        // Touch `body` so SwiftUI's view-building pipeline runs at least once.
        // Crashes on missing public surface (e.g. accidental private fields)
        // surface here.
        let tile = LGKPITile(
            value: "1234",
            label: "POINTS",
            icon: "mappin.and.ellipse",
            tint: .orange
        )
        _ = tile.body
    }

    func testNonEmptyLabelAcceptedWithSingleCharacter() {
        let tile = LGKPITile(value: "0", label: "A", icon: "circle", tint: .red)
        XCTAssertEqual(tile.label, "A")
    }
}

#endif
