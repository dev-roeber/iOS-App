import Foundation
import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Phase-6 — Feature-Flag-Resolver. Linux-deterministisch über injizierte
/// Argumente/Environment.
final class LocalTimelineFeatureFlagsTests: XCTestCase {

    func testDefaultDisabledOnEmptyEnvironment() {
        let f = LocalTimelineFeatureFlags.resolve(arguments: [], environment: [:])
        XCTAssertFalse(f.isLocalTimelineStoreEnabled)
    }

    func testEnabledViaEnvOne() {
        let f = LocalTimelineFeatureFlags.resolve(
            arguments: [],
            environment: ["LH2GPX_LOCAL_TIMELINE_STORE": "1"])
        XCTAssertTrue(f.isLocalTimelineStoreEnabled)
    }

    func testEnabledViaEnvTrueCaseInsensitive() {
        for value in ["true", "TRUE", "True", "yes", "on"] {
            let f = LocalTimelineFeatureFlags.resolve(
                arguments: [],
                environment: ["LH2GPX_LOCAL_TIMELINE_STORE": value])
            XCTAssertTrue(f.isLocalTimelineStoreEnabled, "value=\(value)")
        }
    }

    func testEnabledViaDoubleDashArg() {
        let f = LocalTimelineFeatureFlags.resolve(
            arguments: ["progname", "--LH2GPX_LOCAL_TIMELINE_STORE"],
            environment: [:])
        XCTAssertTrue(f.isLocalTimelineStoreEnabled)
    }

    func testEnabledViaBareArg() {
        let f = LocalTimelineFeatureFlags.resolve(
            arguments: ["progname", "LH2GPX_LOCAL_TIMELINE_STORE"],
            environment: [:])
        XCTAssertTrue(f.isLocalTimelineStoreEnabled)
    }

    func testDisabledViaEnvFalseOrZero() {
        for value in ["0", "false", "no", "off", "", "  "] {
            let f = LocalTimelineFeatureFlags.resolve(
                arguments: [],
                environment: ["LH2GPX_LOCAL_TIMELINE_STORE": value])
            XCTAssertFalse(f.isLocalTimelineStoreEnabled, "value=\(value)")
        }
    }

    func testEnvOverridesAbsenceButArgWins() {
        // Arg present, env absent → enabled
        let a = LocalTimelineFeatureFlags.resolve(
            arguments: ["--LH2GPX_LOCAL_TIMELINE_STORE"],
            environment: [:])
        XCTAssertTrue(a.isLocalTimelineStoreEnabled)
        // Env disabled, arg present → enabled
        let b = LocalTimelineFeatureFlags.resolve(
            arguments: ["--LH2GPX_LOCAL_TIMELINE_STORE"],
            environment: ["LH2GPX_LOCAL_TIMELINE_STORE": "0"])
        XCTAssertTrue(b.isLocalTimelineStoreEnabled)
    }

    func testResolveFromProcessReturnsValue() {
        // Smoke: Resolver darf nicht crashen, Default ist deaktiviert solange
        // CI-Runner das Flag nicht gesetzt hat.
        _ = LocalTimelineFeatureFlags.resolveFromProcess()
    }
}
