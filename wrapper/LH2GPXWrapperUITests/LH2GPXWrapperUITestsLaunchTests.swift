//
//  LH2GPXWrapperUITestsLaunchTests.swift
//  LH2GPXWrapperUITests
//
//  Created by Sebastian on 17.03.26.
//

import XCTest

final class LH2GPXWrapperUITestsLaunchTests: XCTestCase {
    private enum LaunchArgument {
        static let uiTesting = "LH2GPX_UI_TESTING"
        static let resetPersistence = "LH2GPX_RESET_PERSISTENCE"
    }

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += [LaunchArgument.uiTesting, LaunchArgument.resetPersistence]
        app.launch()

        XCTAssertTrue(app.buttons["Load Demo Data"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
