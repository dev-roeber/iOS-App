import XCTest

final class LGTabContainerUITests: XCTestCase {
    @MainActor
    func testLiquidGlassTabContainerShowsFiveTabsByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "LH2GPX_UI_TESTING",
            "LH2GPX_RESET_PERSISTENCE"
        ]
        app.launch()

        let demoButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Demo Data'")
        ).firstMatch
        XCTAssertTrue(demoButton.waitForExistence(timeout: 8))
        demoButton.tap()

        // Liquid-Glass-Tab-Container ist Standard ab 1.1.0, kein Toggle mehr.
        // Erwartung: 5-Tab-Layout (Karte/Tage/Live/Insights/Suche) auf iPhone iOS 26.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        XCTAssertEqual(tabBar.buttons.count, 5)
    }
}
