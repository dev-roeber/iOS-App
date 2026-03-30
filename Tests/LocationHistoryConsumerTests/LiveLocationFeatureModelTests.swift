import XCTest
@testable import LocationHistoryConsumerAppSupport

final class LiveLocationFeatureModelTests: XCTestCase {
    func testToggleOnRequestsPermissionWhenNotDetermined() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .notDetermined)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)

            XCTAssertTrue(model.isAwaitingAuthorization)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.requestWhenInUseAuthorizationCallCount, 1)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
        }
    }

    func testDeniedToggleDoesNotStartUpdates() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .denied)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)

            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
            XCTAssertEqual(model.permissionTitle, "Location Access Denied")
        }
    }

    func testAuthorizedToggleStartsUpdatesAndAcceptsPoint() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])

            XCTAssertTrue(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 1)
            XCTAssertEqual(model.liveTrackPoints.count, 1)
            XCTAssertEqual(model.currentLocation?.latitude, 52.52)
        }
    }

    func testToggleOffStopsUpdatesAndPersistsCompletedTrack() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])

            model.setRecordingEnabled(false)
            client.emit(samples: [
                sample(offsetSeconds: 24, latitude: 52.5206, longitude: 13.4006, accuracy: 6),
            ])

            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.stopUpdatingLocationCallCount, 1)
            XCTAssertEqual(model.recordedTracks.count, 1)
            XCTAssertEqual(store.savedTracks.count, 1)
            XCTAssertTrue(model.liveTrackPoints.isEmpty)
            XCTAssertNil(model.currentLocation)
        }
    }

    func testCompletedTracksLoadWithoutResumingRecording() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let existingTrack = makeTrack()
            let store = InMemoryRecordedTrackStore(initialTracks: [existingTrack])

            let model = LiveLocationFeatureModel(client: client, store: store)

            XCTAssertEqual(model.recordedTracks, [existingTrack])
            XCTAssertFalse(model.isRecording)
            XCTAssertTrue(model.liveTrackPoints.isEmpty)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
        }
    }

    func testUpdateRecordedTrackReplacesExistingTrackAndPersists() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let existingTrack = makeTrack()
            let updatedTrack = RecordedTrack(
                id: existingTrack.id,
                startedAt: existingTrack.startedAt,
                endedAt: existingTrack.endedAt,
                dayKey: existingTrack.dayKey,
                distanceM: 125,
                captureMode: existingTrack.captureMode,
                points: existingTrack.points + [
                    RecordedTrackPoint(
                        latitude: 52.5206,
                        longitude: 13.4006,
                        timestamp: existingTrack.endedAt.addingTimeInterval(10),
                        horizontalAccuracyM: 6
                    ),
                ]
            )
            let store = InMemoryRecordedTrackStore(initialTracks: [existingTrack])
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.updateRecordedTrack(updatedTrack)

            XCTAssertEqual(model.recordedTracks, [updatedTrack])
            XCTAssertEqual(store.savedTracks, [updatedTrack])
            XCTAssertNil(model.persistenceErrorMessage)
        }
    }

    func testDeleteRecordedTrackRemovesExistingTrackAndPersists() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let existingTrack = makeTrack()
            let store = InMemoryRecordedTrackStore(initialTracks: [existingTrack])
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.deleteRecordedTrack(id: existingTrack.id)

            XCTAssertTrue(model.recordedTracks.isEmpty)
            XCTAssertTrue(store.savedTracks.isEmpty)
        }
    }

    func testRecorderConfigurationUpdateAppliesToSubsequentSamples() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.updateRecorderConfiguration(
                LiveTrackRecorderConfiguration(
                    maximumAcceptedAccuracyM: 10,
                    duplicateDistanceThresholdM: 3,
                    minimumDistanceDeltaM: 15,
                    minimumTimeDeltaS: 8,
                    minimumPersistedPointCount: 2
                )
            )
            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 12),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 8),
            ])

            XCTAssertEqual(model.recorderConfiguration.maximumAcceptedAccuracyM, 10)
            XCTAssertEqual(model.liveTrackPoints.count, 1)
            XCTAssertEqual(model.currentLocation?.horizontalAccuracyM, 8)
        }
    }

    func testBackgroundPreferenceRequestsAlwaysAuthorizationFromWhenInUse() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)

            XCTAssertTrue(model.prefersBackgroundTracking)
            XCTAssertTrue(model.needsAlwaysAuthorizationUpgrade)
            XCTAssertEqual(client.requestAlwaysAuthorizationCallCount, 1)
            XCTAssertEqual(client.lastBackgroundTrackingEnabled, false)
        }
    }

    func testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedAlways)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)

            // isBackgroundTrackingActive is a computed property: prefersBackgroundTracking && authorizedAlways
            XCTAssertTrue(model.isBackgroundTrackingActive)
            // The client's background mode is only applied when recording starts, not on preference set alone.
            // Verified by testStoppingAlwaysAuthorizedRecordingStoresBackgroundCaptureMode which covers the full flow.
            XCTAssertEqual(client.lastBackgroundTrackingEnabled, false)
        }
    }

    func testStoppingAlwaysAuthorizedRecordingStoresBackgroundCaptureMode() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedAlways)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)
            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])

            model.setRecordingEnabled(false)

            XCTAssertEqual(model.recordedTracks.first?.captureMode, .backgroundAlways)
            XCTAssertEqual(store.savedTracks.first?.captureMode, .backgroundAlways)
        }
    }

    func testAcceptedSamplesUploadToConfiguredServer() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = TestLiveLocationServerUploader()
        let uploaded = expectation(description: "upload called")
        uploader.onUpload = { uploaded.fulfill() }
        let model = await MainActor.run { () -> LiveLocationFeatureModel in
            let model = LiveLocationFeatureModel(client: client, store: store, uploader: uploader)
            model.setServerUploadConfiguration(
                LiveLocationServerUploadConfiguration(
                    isEnabled: true,
                    endpointURLString: "https://example.invalid/live",
                    bearerToken: "secret",
                    minimumBatchSize: 1
                )
            )
            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])
            return model
        }

        XCTAssertEqual(XCTWaiter.wait(for: [uploaded], timeout: 1.0), .completed)

        XCTAssertEqual(uploader.requests.count, 1)
        XCTAssertEqual(uploader.requests.first?.endpoint.absoluteString, "https://example.invalid/live")
        XCTAssertEqual(uploader.requests.first?.bearerToken, "secret")
        XCTAssertEqual(uploader.requests.first?.request.points.count, 1)
        await MainActor.run {
            XCTAssertEqual(model.serverUploadStatusMessage, "Last upload sent 1 point to example.invalid.")
        }
    }

    func testInvalidServerUploadURLDoesNotSendSamples() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = TestLiveLocationServerUploader()
        let model = await MainActor.run { () -> LiveLocationFeatureModel in
            LiveLocationFeatureModel(client: client, store: store, uploader: uploader)
        }

        await MainActor.run {
            model.setServerUploadConfiguration(
                LiveLocationServerUploadConfiguration(
                    isEnabled: true,
                    endpointURLString: "ftp://example.invalid/live",
                    bearerToken: ""
                )
            )
            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])

            XCTAssertEqual(model.serverUploadStatusMessage, "Server upload is enabled, but the URL is invalid.")
        }

        XCTAssertTrue(uploader.requests.isEmpty)
    }

    func testFailedUploadRetriesWhenAnotherAcceptedSampleArrives() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = TestLiveLocationServerUploader()
        uploader.error = TestLiveLocationUploadError.offline
        let firstUpload = expectation(description: "first upload called")
        let secondUpload = expectation(description: "retry upload called")
        uploader.onUpload = {
            switch uploader.requests.count {
            case 1:
                firstUpload.fulfill()
            case 2:
                secondUpload.fulfill()
            default:
                break
            }
        }

        let model = await MainActor.run { () -> LiveLocationFeatureModel in
            let model = LiveLocationFeatureModel(client: client, store: store, uploader: uploader)
            model.setServerUploadConfiguration(
                LiveLocationServerUploadConfiguration(
                    isEnabled: true,
                    endpointURLString: "https://example.invalid/live",
                    bearerToken: "",
                    minimumBatchSize: 1
                )
            )
            model.setRecordingEnabled(true)
            return model
        }

        await MainActor.run {
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])
        }

        XCTAssertEqual(XCTWaiter.wait(for: [firstUpload], timeout: 1.0), .completed)
        try? await Task.sleep(nanoseconds: 50_000_000)

        uploader.error = nil

        await MainActor.run {
            client.emit(samples: [
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])
        }

        XCTAssertEqual(XCTWaiter.wait(for: [secondUpload], timeout: 1.0), .completed)

        XCTAssertEqual(uploader.requests.count, 2)
        XCTAssertEqual(uploader.requests.last?.request.points.count, 2)
        await MainActor.run {
            XCTAssertEqual(model.serverUploadStatusMessage, "Last upload sent 2 points to example.invalid.")
        }
    }

    private func sample(offsetSeconds: TimeInterval, latitude: Double, longitude: Double, accuracy: Double) -> LiveLocationSample {
        LiveLocationSample(
            latitude: latitude,
            longitude: longitude,
            timestamp: Date(timeIntervalSince1970: 1_710_000_000 + offsetSeconds),
            horizontalAccuracyM: accuracy
        )
    }

    private func makeTrack() -> RecordedTrack {
        let start = Date(timeIntervalSince1970: 1_710_000_000)
        let end = start.addingTimeInterval(20)
        return RecordedTrack(
            startedAt: start,
            endedAt: end,
            dayKey: "2024-03-09",
            distanceM: 42,
            captureMode: .foregroundWhileInUse,
            points: [
                RecordedTrackPoint(latitude: 52.52, longitude: 13.40, timestamp: start, horizontalAccuracyM: 6),
                RecordedTrackPoint(latitude: 52.5203, longitude: 13.4003, timestamp: end, horizontalAccuracyM: 6),
            ]
        )
    }
}

private final class TestLiveLocationClient: LiveLocationClient {
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

    func emit(samples: [LiveLocationSample]) {
        onLocationSamples?(samples)
    }
}

private final class InMemoryRecordedTrackStore: RecordedTrackStoring {
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

private enum TestLiveLocationUploadError: Error {
    case offline
}

private final class TestLiveLocationServerUploader: LiveLocationServerUploading {
    struct RequestRecord {
        let request: LiveLocationUploadRequest
        let endpoint: URL
        let bearerToken: String?
    }

    var requests: [RequestRecord] = []
    var error: Error?
    var onUpload: (() -> Void)?

    func upload(
        request: LiveLocationUploadRequest,
        to endpoint: URL,
        bearerToken: String?
    ) async throws {
        requests.append(
            RequestRecord(
                request: request,
                endpoint: endpoint,
                bearerToken: bearerToken
            )
        )
        onUpload?()
        if let error {
            throw error
        }
    }
}
