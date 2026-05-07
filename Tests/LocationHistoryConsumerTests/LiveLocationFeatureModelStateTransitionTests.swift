import XCTest
import LocationHistoryConsumerAppSupport

/// Multi-step authorization-state transition coverage for
/// `LiveLocationFeatureModel` (audit P1).
///
/// `LiveLocationFeatureModel.RecordingStartState` is `private`, so the
/// transitions are asserted through the observable surface
/// (`isAwaitingAuthorization`, `isRecording`, `permissionTitle`,
/// `startUpdatingLocationCallCount`) rather than direct enum comparison.
/// The mock client/store from `LiveLocationFeatureModelTests` are `private`
/// and not reusable; promoting them is outside this audit ticket, so this
/// file uses a small inline mock pair instead (per task fallback).
final class LiveLocationFeatureModelStateTransitionTests: XCTestCase {
    func testRecordingTransitionsThroughAuthorizationStates() {
        MainActor.assumeIsolated {
            let client = StateTransitionMockLiveLocationClient(authorization: .notDetermined)
            let store = StateTransitionInMemoryRecordedTrackStore()
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
            let client = StateTransitionMockLiveLocationClient(authorization: .notDetermined)
            let store = StateTransitionInMemoryRecordedTrackStore()
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

private final class StateTransitionMockLiveLocationClient: LiveLocationClient {
    var authorization: LiveLocationAuthorization
    var onAuthorizationChange: ((LiveLocationAuthorization) -> Void)?
    var onLocationSamples: (([LiveLocationSample]) -> Void)?

    private(set) var requestWhenInUseAuthorizationCallCount = 0
    private(set) var requestAlwaysAuthorizationCallCount = 0
    private(set) var startUpdatingLocationCallCount = 0
    private(set) var stopUpdatingLocationCallCount = 0
    private(set) var lastBackgroundTrackingEnabled = false

    init(authorization: LiveLocationAuthorization) {
        self.authorization = authorization
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
    }

    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCallCount += 1
    }

    func setBackgroundTrackingEnabled(_ enabled: Bool) {
        lastBackgroundTrackingEnabled = enabled
    }

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }

    func emitAuthorization(_ authorization: LiveLocationAuthorization) {
        self.authorization = authorization
        onAuthorizationChange?(authorization)
    }
}

private final class StateTransitionInMemoryRecordedTrackStore: RecordedTrackStoring {
    private let initialTracks: [RecordedTrack]
    private(set) var savedTracks: [RecordedTrack]

    init(initialTracks: [RecordedTrack] = []) {
        self.initialTracks = initialTracks
        self.savedTracks = initialTracks
    }

    func loadTracks() throws -> [RecordedTrack] {
        initialTracks
    }

    func saveTracks(_ tracks: [RecordedTrack]) throws {
        savedTracks = tracks
    }
}
