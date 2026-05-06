import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveStatusResolverTests: XCTestCase {

    // MARK: - Permission terminal states

    func testDeniedDominatesEverything() {
        let status = LiveStatusResolver.resolve(
            authorization: .denied,
            isAwaitingAuthorization: false,
            isRecording: true,           // even while "recording" (stale flag)
            needsAlwaysUpgrade: true,
            currentAccuracyM: 12         // and with a fresh fix
        )
        XCTAssertEqual(status, .permissionDenied)
    }

    func testRestrictedDominates() {
        let status = LiveStatusResolver.resolve(
            authorization: .restricted,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 8
        )
        XCTAssertEqual(status, .permissionRestricted)
    }

    func testNotDeterminedReturnsPermissionRequiredAwaiting() {
        let status = LiveStatusResolver.resolve(
            authorization: .notDetermined,
            isAwaitingAuthorization: true,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: nil
        )
        XCTAssertEqual(status, .permissionRequired(awaiting: true))
    }

    func testNotDeterminedReturnsPermissionRequiredIdle() {
        let status = LiveStatusResolver.resolve(
            authorization: .notDetermined,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: nil
        )
        XCTAssertEqual(status, .permissionRequired(awaiting: false))
    }

    // MARK: - Background upgrade

    func testBackgroundUpgradePendingWhenAuthorizedWhenInUse() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: true,
            currentAccuracyM: 15
        )
        XCTAssertEqual(status, .backgroundUpgradePending)
    }

    // MARK: - Acquiring fix (no accuracy yet)

    func testAcquiringFixWhenAuthorizedAndNoAccuracy() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: nil
        )
        XCTAssertEqual(status, .acquiringFix)
    }

    func testRecordingAcquiringWhenRecordingAndNoAccuracy() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedAlways,
            isAwaitingAuthorization: false,
            isRecording: true,
            needsAlwaysUpgrade: false,
            currentAccuracyM: nil
        )
        XCTAssertEqual(status, .recordingAcquiring)
    }

    func testNegativeAccuracyTreatedAsAcquiring() {
        // Negative accuracy is CoreLocation's "no valid fix" sentinel.
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: -1
        )
        XCTAssertEqual(status, .acquiringFix)
    }

    // MARK: - Ready (idle, with fix)

    func testReadyGoodForLowAccuracy() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 15
        )
        XCTAssertEqual(status, .readyGood(accuracyM: 15))
    }

    func testReadyWeakAtThreshold() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedAlways,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 30
        )
        XCTAssertEqual(status, .readyWeak(accuracyM: 30))
    }

    func testReadyWeakForHighAccuracyValue() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: false,
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 40
        )
        XCTAssertEqual(status, .readyWeak(accuracyM: 40))
    }

    // MARK: - Recording (with fix)

    func testRecordingGoodWhenAccuracyBelowThreshold() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedAlways,
            isAwaitingAuthorization: false,
            isRecording: true,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 15
        )
        XCTAssertEqual(status, .recordingGood(accuracyM: 15))
    }

    func testRecordingWeakWhenAccuracyAboveThreshold() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedAlways,
            isAwaitingAuthorization: false,
            isRecording: true,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 40
        )
        XCTAssertEqual(status, .recordingWeak(accuracyM: 40))
    }

    // MARK: - Edge: awaiting flag is ignored when authorization is granted

    func testAwaitingFlagIgnoredWhenAlreadyAuthorized() {
        let status = LiveStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            isAwaitingAuthorization: true,    // stale awaiting flag
            isRecording: false,
            needsAlwaysUpgrade: false,
            currentAccuracyM: 10
        )
        XCTAssertEqual(status, .readyGood(accuracyM: 10))
    }

    // MARK: - Helper flags

    func testIsPermissionStateCoversAllPermissionVariants() {
        XCTAssertTrue(LiveStatus.permissionDenied.isPermissionState)
        XCTAssertTrue(LiveStatus.permissionRestricted.isPermissionState)
        XCTAssertTrue(LiveStatus.permissionRequired(awaiting: false).isPermissionState)
        XCTAssertTrue(LiveStatus.backgroundUpgradePending.isPermissionState)
        XCTAssertFalse(LiveStatus.acquiringFix.isPermissionState)
        XCTAssertFalse(LiveStatus.readyGood(accuracyM: 5).isPermissionState)
        XCTAssertFalse(LiveStatus.recordingGood(accuracyM: 5).isPermissionState)
    }

    func testMapOverlayHintTriggersForAcquiringAndPermission() {
        XCTAssertTrue(LiveStatus.acquiringFix.shouldShowMapOverlayHint)
        XCTAssertTrue(LiveStatus.recordingAcquiring.shouldShowMapOverlayHint)
        XCTAssertTrue(LiveStatus.permissionDenied.shouldShowMapOverlayHint)
        XCTAssertFalse(LiveStatus.readyGood(accuracyM: 8).shouldShowMapOverlayHint)
        XCTAssertFalse(LiveStatus.recordingWeak(accuracyM: 50).shouldShowMapOverlayHint)
        XCTAssertFalse(LiveStatus.backgroundUpgradePending.shouldShowMapOverlayHint)
    }
}
