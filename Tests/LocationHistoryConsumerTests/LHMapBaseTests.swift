import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LHMapBaseTests: XCTestCase {

    // MARK: - layersBadge

    func test_layersBadge_zeroOfFour() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: 0)
        XCTAssertEqual(badge, "LAYERS 0/4")
    }

    func test_layersBadge_partial() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: 2)
        XCTAssertEqual(badge, "LAYERS 2/4")
    }

    func test_layersBadge_full() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: 4)
        XCTAssertEqual(badge, "LAYERS 4/4")
    }

    func test_layersBadge_clampsNegative() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: -5)
        XCTAssertEqual(badge, "LAYERS 0/4")
    }

    func test_layersBadge_clampsAboveTotal() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: 99)
        XCTAssertEqual(badge, "LAYERS 4/4")
    }

    func test_layersBadge_germanWordPassthrough() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "EBENEN", activeCount: 1)
        XCTAssertEqual(badge, "EBENEN 1/4")
    }

    func test_layersBadge_customTotal() {
        let badge = LHMapBase.layersBadge(localizedLayersWord: "LAYERS", activeCount: 2, total: 3)
        XCTAssertEqual(badge, "LAYERS 2/3")
    }

    // MARK: - floatingControlTopInset

    func test_floatingControlTopInset_addsTwelvePoints() {
        XCTAssertEqual(LHMapBase.floatingControlTopInset(deviceTopSafeInset: 0), 12)
        XCTAssertEqual(LHMapBase.floatingControlTopInset(deviceTopSafeInset: 47), 59)
        XCTAssertEqual(LHMapBase.floatingControlTopInset(deviceTopSafeInset: 59), 71)
    }

    func test_totalLayerSlots_isFour() {
        XCTAssertEqual(LHMapBase.totalLayerSlots, 4)
    }

    // MARK: - attributionGuardBottomInset

    func test_attributionGuard_isThirtyTwoPoints() {
        XCTAssertEqual(LHMapBase.attributionGuardBottomInset, 32)
    }

    // MARK: - bottomSheetTabBarClearance

    func test_bottomSheetTabBarClearance_defaultsToStandardTabBarHeight() {
        XCTAssertEqual(
            LHMapBase.bottomSheetTabBarClearance(deviceBottomSafeInset: 34),
            49
        )
    }

    func test_bottomSheetTabBarClearance_clampsNegative() {
        XCTAssertEqual(
            LHMapBase.bottomSheetTabBarClearance(
                deviceBottomSafeInset: 0,
                tabBarBaseHeight: -10
            ),
            0
        )
    }

    func test_bottomSheetTabBarClearance_customTabBarHeight() {
        XCTAssertEqual(
            LHMapBase.bottomSheetTabBarClearance(
                deviceBottomSafeInset: 0,
                tabBarBaseHeight: 64
            ),
            64
        )
    }

    func test_tabBarStandardHeight_isFortyNine() {
        XCTAssertEqual(LHMapBase.tabBarStandardHeight, 49)
    }
}
