import XCTest

final class LGTabContainerUITests: XCTestCase {
    @MainActor
    func testLiquidGlassTabContainerShowsFiveTabsWhenEnabled() throws {
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

        let actions = app.buttons["appshell.actionsMenu"]
        XCTAssertTrue(actions.waitForExistence(timeout: 8))
        actions.tap()

        let options = app.buttons["appshell.menu.options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()

        let general = app.cells.containing(.staticText, identifier: "General").firstMatch
        if general.waitForExistence(timeout: 5) {
            general.tap()
        }

        let toggle = app.switches["options.general.liquidGlassTabContainer"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" {
            toggle.tap()
        }

        app.buttons["Done"].tap()
        XCTAssertEqual(app.tabBars.buttons.count, 5)
    }
}
