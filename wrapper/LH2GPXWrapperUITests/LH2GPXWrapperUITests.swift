import XCTest

final class LH2GPXWrapperUITests: XCTestCase {
    private enum LaunchArgument {
        static let uiTesting = "LH2GPX_UI_TESTING"
        static let resetPersistence = "LH2GPX_RESET_PERSISTENCE"
    }

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - App Store Screenshots
    //
    // Run on iPhone 17 Pro Max for iphone/ screenshots.
    // Run on iPad Pro 13-inch (M5) for ipad/ screenshots.
    //
    // The output path suffix (iphone/ipad) must be adjusted per run.

    @MainActor
    func testAppStoreScreenshots() throws {
        // Adjust per simulator run: "iphone" or "ipad"
        let deviceFolder = "iphone"
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("lh2gpx_screenshots/\(deviceFolder)").path
        try FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )

        let app = XCUIApplication()
        app.launchArguments += [LaunchArgument.uiTesting, LaunchArgument.resetPersistence]
        app.launch()
        sleep(1)

        // 1. Import / empty state
        saveScreenshot(app, to: "\(outputDir)/01_import_state.png")

        // 2. Load Demo Data
        let demoButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Demo Data'")
        ).firstMatch
        guard demoButton.waitForExistence(timeout: 5) else {
            XCTFail("Demo button not found"); return
        }
        demoButton.tap()
        sleep(3)

        // On iPhone: go back to see the day list (auto-navigates to detail)
        // On iPad: back button may not exist – skip
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
            sleep(1)
        }

        // 3. Day list / overview
        saveScreenshot(app, to: "\(outputDir)/02_day_list.png")

        // 4. Tap first day cell (non-fatal: iPad may not need tap)
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            sleep(2)
        }

        // 5. Day detail – top (map)
        saveScreenshot(app, to: "\(outputDir)/03_day_detail.png")

        // 6. Day detail – scrolled (stats + sections)
        app.swipeUp()
        sleep(1)
        saveScreenshot(app, to: "\(outputDir)/04_day_detail_stats.png")
    }

    @MainActor
    func testDeviceSmokeNavigationAndActions() throws {
        let app = XCUIApplication()
        app.launchArguments += [LaunchArgument.uiTesting, LaunchArgument.resetPersistence]
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        let demoButton = app.buttons["Load Demo Data"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        demoButton.tap()

        let overviewTab = app.tabBars.buttons["Overview"]
        XCTAssertTrue(overviewTab.waitForExistence(timeout: 10))

        overviewTab.tap()
        let heatmapButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Heatmap'")).firstMatch
        XCTAssertTrue(revealElement(heatmapButton, in: app))
        heatmapButton.tap()
        XCTAssertTrue(app.navigationBars["Heatmap"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5))
        insightsTab.tap()

        let shareButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Share'")).firstMatch
        XCTAssertTrue(revealElement(shareButton, in: app))
        shareButton.tap()
        XCTAssertTrue(app.buttons["Share Chart"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        let exportTab = app.tabBars.buttons["Export"]
        XCTAssertTrue(exportTab.waitForExistence(timeout: 5))
        exportTab.tap()

        // Verify the export bar is rendered (export action button present, possibly disabled).
        // SwiftUI TabView keeps all tabs in memory, so cell-based queries are unreliable.
        // Instead, verify the export action button exists and tap a coordinate to select a day.
        let exportAction = app.buttons.matching(identifier: "export.action.primary").firstMatch
        XCTAssertTrue(exportAction.waitForExistence(timeout: 10), "export.action.primary button not found")

        // Tap in the upper portion of the list area to select the first visible day row.
        // After selection the export button becomes enabled and the fileExporter is triggered.
        let listTapTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        listTapTarget.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        if exportAction.isEnabled {
            exportAction.tap()
            XCTAssertTrue(waitForExportPresentation(in: app, timeout: 10))
            dismissPresentedExportUI(in: app)
        } else {
            // Export button remained disabled: list likely scrolled past tapped cell.
            // Scroll down and retry once.
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            listTapTarget.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            if exportAction.isEnabled {
                exportAction.tap()
                XCTAssertTrue(waitForExportPresentation(in: app, timeout: 10))
                dismissPresentedExportUI(in: app)
            }
        }

        let liveTab = app.tabBars.buttons["Live"]
        XCTAssertTrue(liveTab.waitForExistence(timeout: 5))
        liveTab.tap()

        // The recording button's accessibility label combines title + subtitle texts.
        let startRecordingButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Start Recording'")
        ).firstMatch
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 10), "Start Recording button not found")
        startRecordingButton.tap()
        allowLocationAccessIfNeeded()

        let stopRecordingButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Stop Recording'")
        ).firstMatch
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 15), "Stop Recording button not found")
        stopRecordingButton.tap()

        let startRecordingAgain = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Start Recording'")
        ).firstMatch
        XCTAssertTrue(startRecordingAgain.waitForExistence(timeout: 10), "Start Recording button not reappeared after stop")
    }

    // MARK: - Helpers

    private func saveScreenshot(_ app: XCUIApplication, to path: String) {
        let screenshot = XCUIScreen.main.screenshot()
        do {
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        } catch {
            XCTFail("Screenshot save failed: \(error)")
        }
    }

    @MainActor
    private func revealElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 5), element.isHittable {
            return true
        }

        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable {
                return true
            }

            if let scrollView = primaryScrollableContainer(in: app) {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        if element.exists && element.isHittable {
            return true
        }

        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable {
                return true
            }

            if let scrollView = primaryScrollableContainer(in: app) {
                scrollView.swipeDown()
            } else {
                app.swipeDown()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        return element.exists && element.isHittable
    }

    @MainActor
    private func primaryScrollableContainer(in app: XCUIApplication) -> XCUIElement? {
        let candidates = [
            app.scrollViews.firstMatch,
            app.tables.firstMatch,
            app.collectionViews.firstMatch
        ]

        return candidates.first(where: { $0.exists })
    }

    @MainActor
    private func waitForExportPresentation(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let started = Date()
        while Date().timeIntervalSince(started) < timeout {
            if app.buttons["Cancel"].exists ||
                app.navigationBars.buttons["Cancel"].exists ||
                springboard.buttons["Cancel"].exists ||
                springboard.buttons["Save"].exists ||
                springboard.buttons["Move"].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    @MainActor
    private func dismissPresentedExportUI(in app: XCUIApplication) {
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
            return
        }
        if app.navigationBars.buttons["Cancel"].exists {
            app.navigationBars.buttons["Cancel"].tap()
            return
        }
        if springboard.buttons["Cancel"].exists {
            springboard.buttons["Cancel"].tap()
        }
    }

    @MainActor
    private func allowLocationAccessIfNeeded() {
        let alertButtons = [
            "Allow While Using App",
            "Allow Once",
            "OK",
            "Beim Verwenden der App erlauben",
            "Einmal erlauben"
        ]

        for label in alertButtons {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return
            }
        }
    }
}
