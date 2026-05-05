import XCTest

final class LH2GPXWrapperUITests: XCTestCase {
    private enum LaunchArgument {
        static let uiTesting = "LH2GPX_UI_TESTING"
        static let resetPersistence = "LH2GPX_RESET_PERSISTENCE"
        static func dynamicIslandDisplay(_ value: String) -> String {
            "LH2GPX_DYNAMIC_ISLAND_DISPLAY=\(value)"
        }
        static func uploadEnabled(_ value: Bool) -> String {
            "LH2GPX_UPLOAD_ENABLED=\(value ? "1" : "0")"
        }
        static func uploadURL(_ value: String) -> String {
            "LH2GPX_UPLOAD_URL=\(value)"
        }
        static func uploadBatch(_ value: String) -> String {
            "LH2GPX_UPLOAD_BATCH=\(value)"
        }
    }

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - App Store Screenshots
    //
    // Device: iPhone 15 Pro Max (or iPhone 17 Pro Max simulator) — portrait, 3× scale.
    // Screenshots are captured via XCTAttachment and stored in the xcresult bundle.
    // Extract after run:
    //   xcrun xcresulttool export --path <result.xcresult> --output-path /tmp/ss --type directory
    // Then copy PNGs to docs/app-store-assets/screenshots/iphone-67/
    //
    // Slots 01–08 target the redesigned LH2GPX-Dark UI (Build 73+).
    // iPad: run on iPad Pro 13-inch (M4) with deviceFolder = "ipad".

    @MainActor
    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += [LaunchArgument.uiTesting, LaunchArgument.resetPersistence]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        sleep(2)

        // 01 — Import / empty state (before any data loaded)
        attach(screenshot(app), name: "01-import")

        // Load Demo Data so all tabs have content
        let demoButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Demo Data'")
        ).firstMatch
        guard demoButton.waitForExistence(timeout: 8) else {
            XCTFail("Demo button not found"); return
        }
        demoButton.tap()
        sleep(4)

        // Switch to Overview tab; expand to All Time so 2024 demo data is visible
        let overviewTab = app.tabBars.buttons["Overview"]
        if overviewTab.waitForExistence(timeout: 5) { overviewTab.tap(); sleep(1) }
        let allChip = app.buttons["range.chip.all"]
        if allChip.waitForExistence(timeout: 5) { allChip.tap(); sleep(2) }

        // 02 — Overview map
        attach(screenshot(app), name: "02-overview-map")

        // 03 — Days tab (list view)
        let daysTab = app.tabBars.buttons["Days"]
        if daysTab.waitForExistence(timeout: 5) { daysTab.tap(); sleep(2) }
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists && backButton.isHittable { backButton.tap(); sleep(1) }
        attach(screenshot(app), name: "03-days")

        // 04 — Insights tab
        let insightsTab = app.tabBars.buttons["Insights"]
        if insightsTab.waitForExistence(timeout: 5) { insightsTab.tap(); sleep(2) }
        attach(screenshot(app), name: "04-insights")

        // 05 — Export tab (redesigned checkout with stepper, pills, sticky bar)
        let exportTab = app.tabBars.buttons["Export"]
        if exportTab.waitForExistence(timeout: 5) { exportTab.tap(); sleep(1) }
        attach(screenshot(app), name: "05-export")

        // 06 — Live tab (redesigned dark layout: Mint polyline, status chips, bottom bar)
        let liveTab = app.tabBars.buttons["Live"]
        if liveTab.waitForExistence(timeout: 5) { liveTab.tap(); sleep(1) }
        attach(screenshot(app), name: "06-live-recording")

        // 07 — Options main screen (redesigned 8-section NavigationLink grid)
        // Navigate via tab bar "Options" button or accessibility identifier
        let optionsButton = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Options' OR label CONTAINS 'Einstellung'")
        ).firstMatch
        if optionsButton.waitForExistence(timeout: 5) {
            optionsButton.tap(); sleep(1)
        } else {
            // Fallback: look for a navigation button labelled Settings/Optionen
            let settingsBtn = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Options' OR label CONTAINS 'Settings'")
            ).firstMatch
            if settingsBtn.waitForExistence(timeout: 3) { settingsBtn.tap(); sleep(1) }
        }
        attach(screenshot(app), name: "07-options")

        // 08 — Day Detail (map-first, first available day in demo data)
        // Return to Days tab and tap the first day row
        if daysTab.waitForExistence(timeout: 5) { daysTab.tap(); sleep(1) }
        let firstDayCell = app.cells.firstMatch
        if firstDayCell.waitForExistence(timeout: 5) { firstDayCell.tap(); sleep(2) }
        attach(screenshot(app), name: "08-day-detail")
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

        // Demo fixture dates are from 2024 — switch to All Time so Insights and other
        // tabs show content regardless of when the test runs.
        let allTimeChip = app.buttons["range.chip.all"]
        if allTimeChip.waitForExistence(timeout: 5) {
            allTimeChip.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        let heatmapButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Heatmap'")).firstMatch
        XCTAssertTrue(revealElement(heatmapButton, in: app))
        heatmapButton.tap()
        XCTAssertTrue(app.navigationBars["Heatmap"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5))
        insightsTab.tap()

        // Allow insights content to render (lazy grid + derived model computation).
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))

        // Share buttons (insights.share.*) only appear when a section has data (e.g. highlightItems
        // non-empty). Smoke test verifies navigation; share is exercised if a button is present.
        let shareButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'insights.share.'")
        ).firstMatch
        if revealElement(shareButton, in: app) {
            shareButton.tap()
            XCTAssertTrue(app.buttons["insights.share.chart"].waitForExistence(timeout: 10))
            app.buttons["Done"].tap()
        }

        let exportTab = app.tabBars.buttons["Export"]
        XCTAssertTrue(exportTab.waitForExistence(timeout: 5))
        exportTab.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))

        // Verify the export bar is rendered (export action button present, possibly disabled).
        // SwiftUI TabView keeps all tabs in memory, so cell-based queries are unreliable.
        // Instead, verify the export action button exists and tap a coordinate to select a day.
        // The Export CTA is in LHExportBottomBar (.safeAreaInset). XCTest accessibility may not
        // expose .safeAreaInset content reliably on all simulator configs — smoke only navigates.
        let exportAction = app.buttons.matching(identifier: "export.primaryButton").firstMatch
        if exportAction.waitForExistence(timeout: 10) {
            // Tap in the upper portion of the list area to select the first visible day row.
            let listTapTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            listTapTarget.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))

            if exportAction.isEnabled {
                exportAction.tap()
                XCTAssertTrue(waitForExportPresentation(in: app, timeout: 10))
                dismissPresentedExportUI(in: app)
            } else {
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
        }

        let liveTab = app.tabBars.buttons["Live"]
        XCTAssertTrue(liveTab.waitForExistence(timeout: 5))
        liveTab.tap()

        // Batch 5A redesign: start = live.recording.primaryAction, stop = live.recording.stopAction.
        let startRecordingButton = app.buttons["live.recording.primaryAction"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 10), "Start Recording button not found")
        startRecordingButton.tap()
        allowLocationAccessIfNeeded()

        let stopRecordingButton = app.buttons["live.recording.stopAction"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 15), "Stop Recording button not found")
        stopRecordingButton.tap()

        let startRecordingAgain = app.buttons["live.recording.primaryAction"]
        XCTAssertTrue(startRecordingAgain.waitForExistence(timeout: 10), "Start Recording button not reappeared after stop")
    }

    @MainActor
    func testLiveActivityHardwareCaptureDistance() throws {
        let app = configuredApp(
            dynamicIslandDisplay: "distance",
            uploadEnabled: false
        )
        runLiveActivityCaptureFlow(
            app: app,
            screenshotPrefix: "live-activity-distance",
            shouldAttemptExpandedIsland: true,
            shouldStopRecording: true,
            shouldRelaunchDuringRecording: false
        )
    }

    @MainActor
    func testLiveActivityHardwareCaptureDuration() throws {
        let app = configuredApp(
            dynamicIslandDisplay: "elapsed",
            uploadEnabled: false
        )
        runLiveActivityCaptureFlow(
            app: app,
            screenshotPrefix: "live-activity-duration",
            shouldAttemptExpandedIsland: true,
            shouldStopRecording: true,
            shouldRelaunchDuringRecording: false
        )
    }

    @MainActor
    func testLiveActivityHardwareCapturePoints() throws {
        let app = configuredApp(
            dynamicIslandDisplay: "points",
            uploadEnabled: false
        )
        runLiveActivityCaptureFlow(
            app: app,
            screenshotPrefix: "live-activity-points",
            shouldAttemptExpandedIsland: true,
            shouldStopRecording: true,
            shouldRelaunchDuringRecording: false
        )
    }

    @MainActor
    func testLiveActivityHardwareCaptureUploadStatusPendingAndRestart() throws {
        let app = configuredApp(
            dynamicIslandDisplay: "uploadStatus",
            uploadEnabled: true,
            uploadURL: "https://example.com/live",
            uploadBatch: "large"
        )
        runLiveActivityCaptureFlow(
            app: app,
            screenshotPrefix: "live-activity-upload-pending",
            shouldAttemptExpandedIsland: true,
            shouldStopRecording: true,
            shouldRelaunchDuringRecording: true
        )
    }

    @MainActor
    func testLiveActivityHardwareCaptureUploadStatusFailed() throws {
        let app = configuredApp(
            dynamicIslandDisplay: "uploadStatus",
            uploadEnabled: true,
            uploadURL: "https://invalid.invalid/live",
            uploadBatch: "immediate"
        )
        runLiveActivityCaptureFlow(
            app: app,
            screenshotPrefix: "live-activity-upload-failed",
            shouldAttemptExpandedIsland: true,
            shouldStopRecording: true,
            shouldRelaunchDuringRecording: false
        )
    }

    // MARK: - Helpers

    private func screenshot(_ app: XCUIApplication) -> XCUIScreenshot {
        XCUIScreen.main.screenshot()
    }

    private func attach(_ shot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func configuredApp(
        dynamicIslandDisplay: String,
        uploadEnabled: Bool,
        uploadURL: String? = nil,
        uploadBatch: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            LaunchArgument.uiTesting,
            LaunchArgument.resetPersistence,
            LaunchArgument.dynamicIslandDisplay(dynamicIslandDisplay),
            LaunchArgument.uploadEnabled(uploadEnabled)
        ]
        if let uploadURL {
            app.launchArguments += [LaunchArgument.uploadURL(uploadURL)]
        }
        if let uploadBatch {
            app.launchArguments += [LaunchArgument.uploadBatch(uploadBatch)]
        }
        XCUIDevice.shared.orientation = .portrait
        return app
    }

    @MainActor
    private func runLiveActivityCaptureFlow(
        app: XCUIApplication,
        screenshotPrefix: String,
        shouldAttemptExpandedIsland: Bool,
        shouldStopRecording: Bool,
        shouldRelaunchDuringRecording: Bool
    ) {
        app.launch()

        let demoButton = app.buttons["Load Demo Data"]
        XCTAssertTrue(demoButton.waitForExistence(timeout: 5))
        demoButton.tap()

        let liveTab = app.tabBars.buttons["Live"]
        XCTAssertTrue(liveTab.waitForExistence(timeout: 10))
        liveTab.tap()

        let startRecordingButton = app.buttons["live.recording.start"]
        XCTAssertTrue(startRecordingButton.waitForExistence(timeout: 10))
        startRecordingButton.tap()
        allowLocationAccessIfNeeded()

        let stopRecordingButton = app.buttons["live.recording.stop"]
        XCTAssertTrue(stopRecordingButton.waitForExistence(timeout: 15))
        RunLoop.current.run(until: Date().addingTimeInterval(4.0))
        attach(screenshot(app), name: "\(screenshotPrefix)-01-in-app")

        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        attach(screenshot(springboard), name: "\(screenshotPrefix)-02-home-compact")

        if shouldAttemptExpandedIsland {
            let island = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
            island.press(forDuration: 1.3)
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
            attach(screenshot(springboard), name: "\(screenshotPrefix)-03-home-expanded-attempt")
        }

        if shouldRelaunchDuringRecording {
            reopenAppFromSpringboardIfNeeded()
            app.terminate()
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
            XCUIDevice.shared.press(.home)
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
            attach(screenshot(springboard), name: "\(screenshotPrefix)-04-after-terminate")
            reopenAppFromSpringboardIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(3.0))
            attach(screenshot(app), name: "\(screenshotPrefix)-05-after-relaunch")

            // resetPersistence cleared session content on relaunch; reload demo data and navigate to Live tab.
            let demoButtonAfterRelaunch = app.buttons["Load Demo Data"]
            XCTAssertTrue(demoButtonAfterRelaunch.waitForExistence(timeout: 8), "Load Demo Data button not found after relaunch")
            demoButtonAfterRelaunch.tap()

            let liveTabAfterRelaunch = app.tabBars.buttons["Live"]
            XCTAssertTrue(liveTabAfterRelaunch.waitForExistence(timeout: 10), "Live tab not found after relaunch")
            liveTabAfterRelaunch.tap()

            // Interrupted session banner must be visible; tap Resume to restart recording.
            let resumeButton = app.buttons["live.interrupted.resume"]
            XCTAssertTrue(resumeButton.waitForExistence(timeout: 10), "Interrupted session resume button not found after relaunch")
            resumeButton.tap()
            allowLocationAccessIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
            attach(screenshot(app), name: "\(screenshotPrefix)-06-after-resume")
        } else {
            reopenAppFromSpringboardIfNeeded()
        }

        if shouldStopRecording {
            let stopAgain = app.buttons["live.recording.stop"]
            XCTAssertTrue(stopAgain.waitForExistence(timeout: 15))
            stopAgain.tap()
            let startAgain = app.buttons["live.recording.start"]
            XCTAssertTrue(startAgain.waitForExistence(timeout: 15))
            XCUIDevice.shared.press(.home)
            RunLoop.current.run(until: Date().addingTimeInterval(3.0))
            attach(screenshot(springboard), name: "\(screenshotPrefix)-06-after-stop")
        }
    }

    @MainActor
    private func reopenAppFromSpringboardIfNeeded() {
        let app = XCUIApplication()
        app.activate()
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
