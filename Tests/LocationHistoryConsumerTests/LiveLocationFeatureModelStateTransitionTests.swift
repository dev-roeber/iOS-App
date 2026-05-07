import XCTest
import LocationHistoryConsumerAppSupport

/// Multi-step authorization-state transition coverage for
/// `LiveLocationFeatureModel` (audit P1).
///
/// `LiveLocationFeatureModel.RecordingStartState` is `private`, so the
/// transitions are asserted through the observable surface
/// (`isAwaitingAuthorization`, `isRecording`, `permissionTitle`,
/// `startUpdatingLocationCallCount`) rather than direct enum comparison.
/// Shares `MockLiveLocationClient` / `InMemoryRecordedTrackStore` with other
/// LiveLocation tests via `Helpers/MockLiveLocationClient.swift`.
final class LiveLocationFeatureModelStateTransitionTests: XCTestCase {
    func testRecordingTransitionsThroughAuthorizationStates() {
        MainActor.assumeIsolated {
            let client = MockLiveLocationClient(authorization: .notDetermined)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            // Step 1: requestingWhenInUse — setting background preference
            // first ensures the always-upgrade path runs after whenInUse is
            // granted. With .notDetermined this only sets the preference.
            model.setBackgroundTrackingPreference(true)
            XCTAssertTrue(model.prefersBackgroundTracking)

            model.setRecordingEnabled(true)

            XCTAssertTrue(
                model.isAwaitingAuthorization,
                "requestingWhenInUse: model must be awaiting authorization"
            )
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.requestWhenInUseAuthorizationCallCount, 1)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)

            // Step 2: requestingWhenInUse → awaitingAlwaysUpgrade
            client.emitAuthorization(.authorizedWhenInUse)

            XCTAssertTrue(
                model.isAwaitingAuthorization,
                "awaitingAlwaysUpgrade: still awaiting (always-upgrade pending)"
            )
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(model.permissionTitle, "Background Upgrade Pending")
            XCTAssertEqual(client.requestAlwaysAuthorizationCallCount, 1)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)

            // Step 3: awaitingAlwaysUpgrade → readyToStart → recording
            client.emitAuthorization(.authorizedAlways)

            XCTAssertFalse(model.isAwaitingAuthorization)
            XCTAssertTrue(model.isRecording, "readyToStart must immediately advance to recording")
            XCTAssertEqual(client.startUpdatingLocationCallCount, 1)
            XCTAssertTrue(model.isBackgroundTrackingActive)
        }
    }

    func testFailedAuthorizationFromAwaitingAlwaysUpgrade() {
        MainActor.assumeIsolated {
            let client = MockLiveLocationClient(authorization: .notDetermined)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)
            model.setRecordingEnabled(true)

            // Sequence: notDetermined → whenInUse (awaitingAlwaysUpgrade)
            client.emitAuthorization(.authorizedWhenInUse)
            XCTAssertEqual(model.permissionTitle, "Background Upgrade Pending")
            XCTAssertTrue(model.isAwaitingAuthorization)

            // Always-upgrade denied → failedAuthorization for the background
            // recording attempt. The model resolves the upgrade without
            // starting recording.
            client.emitAuthorization(.denied)

            XCTAssertFalse(model.isAwaitingAuthorization)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
            // permissionTitle reflects the denied authorization (no longer the
            // in-progress upgrade prompt).
            XCTAssertNotEqual(model.permissionTitle, "Background Upgrade Pending")
        }
    }
}