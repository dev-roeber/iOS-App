import Foundation
import LocationHistoryConsumerAppSupport

/// Reusable mock `LiveLocationClient` for tests that need to drive
/// authorization changes and observe call counts. Designed to be generic so
/// multiple test files (state-transition, basic feature-model, etc.) can share
/// it.
final class MockLiveLocationClient: LiveLocationClient {
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

    /// Update the stored authorization and notify observers.
    func emitAuthorization(_ authorization: LiveLocationAuthorization) {
        self.authorization = authorization
        onAuthorizationChange?(authorization)
    }

    /// Push location samples through the registered callback.
    func emitLocationSamples(_ samples: [LiveLocationSample]) {
        onLocationSamples?(samples)
    }
}

/// Reusable in-memory `RecordedTrackStoring` for tests that don't need disk
/// persistence. Tracks saved via `saveTracks` are exposed via `savedTracks`.
final class InMemoryRecordedTrackStore: RecordedTrackStoring {
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
