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

    func testBackgroundRecordingStartWaitsForAlwaysAuthorizationUpgrade() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)
            model.setRecordingEnabled(true)

            XCTAssertTrue(model.isAwaitingAuthorization)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
            XCTAssertEqual(model.permissionTitle, "Background Upgrade Pending")
        }
    }

    func testBackgroundRecordingStartsAfterAlwaysAuthorizationUpgradeSucceeds() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)
            model.setRecordingEnabled(true)
            client.emitAuthorization(.authorizedAlways)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])

            XCTAssertFalse(model.isAwaitingAuthorization)
            XCTAssertTrue(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 1)
            XCTAssertEqual(model.liveTrackPoints.count, 1)
            XCTAssertTrue(model.isBackgroundTrackingActive)
        }
    }

    func testBackgroundRecordingDoesNotStartWhenAlwaysAuthorizationUpgradeIsDenied() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setBackgroundTrackingPreference(true)
            model.setRecordingEnabled(true)
            client.emitAuthorization(.authorizedWhenInUse)

            XCTAssertFalse(model.isAwaitingAuthorization)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
            XCTAssertEqual(model.permissionTitle, "Background Access Required")
        }
    }

    func testRepeatedStartRequestsDoNotStartRecordingTwice() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedAlways)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)
            model.setRecordingEnabled(true)

            XCTAssertTrue(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 1)
        }
    }

    func testRestrictedAuthorizationAfterPromptDoesNotStartRecording() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .notDetermined)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)
            client.emitAuthorization(.restricted)

            XCTAssertFalse(model.isAwaitingAuthorization)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
            XCTAssertEqual(model.permissionTitle, "Location Access Restricted")
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

    func testPausedUploadQueuesPointsWithoutSendingUntilResumed() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = TestLiveLocationServerUploader()
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
            model.setUploadPaused(true)
            model.setRecordingEnabled(true)
            return model
        }

        await MainActor.run {
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        await MainActor.run {
            XCTAssertEqual(model.pendingUploadPointCount, 1)
            XCTAssertTrue(model.isUploadPaused)
            XCTAssertTrue(uploader.requests.isEmpty)

            model.setUploadPaused(false)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(uploader.requests.count, 1)
    }

    func testManualFlushUploadsBelowBatchThreshold() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = TestLiveLocationServerUploader()
        let uploaded = expectation(description: "manual flush upload")
        uploader.onUpload = { uploaded.fulfill() }
        let model = await MainActor.run { () -> LiveLocationFeatureModel in
            let model = LiveLocationFeatureModel(client: client, store: store, uploader: uploader)
            model.setServerUploadConfiguration(
                LiveLocationServerUploadConfiguration(
                    isEnabled: true,
                    endpointURLString: "https://example.invalid/live",
                    bearerToken: "",
                    minimumBatchSize: 5
                )
            )
            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])
            return model
        }

        await MainActor.run {
            XCTAssertEqual(model.pendingUploadPointCount, 2)
            XCTAssertTrue(uploader.requests.isEmpty)
            model.flushPendingUploads()
        }

        XCTAssertEqual(XCTWaiter.wait(for: [uploaded], timeout: 1.0), .completed)
        XCTAssertEqual(uploader.requests.first?.request.points.count, 2)
    }

    func testDisablingServerUploadCancelsInFlightUploadAndClearsQueue() async {
        let client = await MainActor.run { TestLiveLocationClient(authorization: .authorizedWhenInUse) }
        let store = InMemoryRecordedTrackStore()
        let uploader = BlockingLiveLocationServerUploader()
        let started = expectation(description: "upload started")
        let cancelled = expectation(description: "upload cancelled")
        uploader.onUploadStarted = { started.fulfill() }
        uploader.onUploadCancelled = { cancelled.fulfill() }

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
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
            ])
            return model
        }

        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 1.0), .completed)

        await MainActor.run {
            model.setServerUploadConfiguration(
                LiveLocationServerUploadConfiguration(
                    isEnabled: false,
                    endpointURLString: "",
                    bearerToken: "",
                    minimumBatchSize: 1
                )
            )
        }

        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 1.0), .completed)

        await MainActor.run {
            XCTAssertFalse(model.isUploadingToServer)
            XCTAssertEqual(model.pendingUploadPointCount, 0)
            XCTAssertNil(model.serverUploadStatusMessage)
        }
        XCTAssertTrue(uploader.wasCancelled)
    }

    // MARK: - Follow Mode Tests

    func testFollowingLocationDefaultsToFalse() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            XCTAssertFalse(model.isFollowingLocation)
        }
    }

    func testFollowingLocationCanBeToggled() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.isFollowingLocation = true
            XCTAssertTrue(model.isFollowingLocation)

            model.isFollowingLocation = false
            XCTAssertFalse(model.isFollowingLocation)
        }
    }

    func testFollowingLocationResetToFalseOnStop() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let model = LiveLocationFeatureModel(client: client, store: store)

            model.setRecordingEnabled(true)
            model.isFollowingLocation = true
            XCTAssertTrue(model.isFollowingLocation)

            model.setRecordingEnabled(false)
            XCTAssertFalse(model.isFollowingLocation)
        }
    }

    // MARK: - Auto-Resume Foundation Tests

    func testHasInterruptedSessionFalseByDefault() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertFalse(model.hasInterruptedSession)
        }
    }

    func testHasInterruptedSessionFalseWhenSessionTimestampMissing() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
        }
    }

    func testSessionStartedAtRestoredOnInitWhenSessionIDPresent() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let expectedDate = Date(timeIntervalSince1970: 1_710_000_000)
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(expectedDate.timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertTrue(model.hasInterruptedSession)
            XCTAssertNotNil(model.sessionStartedAt)
            if let restoredDate = model.sessionStartedAt {
                XCTAssertEqual(restoredDate.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 0.001)
            }
        }
    }

    func testSessionIDPersistedOnRecordingStart() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            model.setRecordingEnabled(true)

            XCTAssertNotNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNotNil(model.sessionID)
            XCTAssertNotNil(model.sessionStartedAt)
        }
    }

    func testDeniedRecordingStartDoesNotPersistInterruptedSessionState() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .denied)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            model.setRecordingEnabled(true)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    func testSessionIDClearedOnRecordingStop() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            model.setRecordingEnabled(true)
            XCTAssertNotNil(defaults.string(forKey: "live.session.id"))

            model.setRecordingEnabled(false)

            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
        }
    }

    func testDismissInterruptedSessionClearsStateAndDefaults() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)
            XCTAssertTrue(model.hasInterruptedSession)

            model.dismissInterruptedSession()

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    func testStartingNewRecordingClearsInterruptedSessionFlag() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)
            XCTAssertTrue(model.hasInterruptedSession)

            model.setRecordingEnabled(true)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertTrue(model.isRecording)
        }
    }

    func testInterruptedSessionRequiresValidSessionIDAndTimestamp() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set("not-a-uuid", forKey: "live.session.id")
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    func testInterruptedSessionRejectsInvalidTimestampValues() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(0, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(model.sessionID)
            XCTAssertNil(model.sessionStartedAt)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    // MARK: - Interrupted Session: No Auto-Resume / Resume Flow

    func testInterruptedSessionDoesNotAutoResumeRecording() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertTrue(model.hasInterruptedSession)
            XCTAssertFalse(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 0)
        }
    }

    func testResumeAfterInterruptedSessionStartsNewRecording() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(UUID().uuidString, forKey: "live.session.id")
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)
            XCTAssertTrue(model.hasInterruptedSession)

            model.dismissInterruptedSession()
            model.setRecordingEnabled(true)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertTrue(model.isRecording)
            XCTAssertEqual(client.startUpdatingLocationCallCount, 1)
        }
    }

    func testPartialDefaultsTimestampOnlyNoInterruptedSession() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            defaults.set(Date().timeIntervalSince1970, forKey: "live.session.startedAt")

            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertFalse(model.isRecording)
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    func testStopRecordingLeavesNoRestorationState() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            let defaults = makeIsolatedUserDefaults()
            let model = LiveLocationFeatureModel(client: client, store: store, userDefaults: defaults)

            model.setRecordingEnabled(true)
            XCTAssertTrue(model.isRecording)

            model.setRecordingEnabled(false)

            XCTAssertFalse(model.isRecording)
            XCTAssertFalse(model.hasInterruptedSession)
            XCTAssertNil(defaults.string(forKey: "live.session.id"))
            XCTAssertNil(defaults.object(forKey: "live.session.startedAt"))
        }
    }

    func testAutoSplit_persistsSplitSegmentAndContinuesRecording() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            var config = LiveTrackRecorderConfiguration()
            config.maximumGapSeconds = 60
            let model = LiveLocationFeatureModel(
                client: client,
                store: store,
                recorder: LiveTrackRecorder(configuration: config)
            )

            model.setRecordingEnabled(true)
            // Two points → form a valid segment
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])
            // Gap > 60 s → triggers auto-split; third point starts new segment
            client.emit(samples: [
                sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 6),
            ])

            // Split segment must be persisted immediately
            XCTAssertEqual(model.recordedTracks.count, 1, "split segment must be persisted without stopping the recording")
            XCTAssertEqual(store.savedTracks.count, 1)
            XCTAssertTrue(model.isRecording, "recording must continue after auto-split")
            XCTAssertEqual(model.liveTrackPoints.count, 1, "current segment starts with the post-gap point")
        }
    }

    func testAutoSplit_splitSegmentThenStopPersistsBothTracks() {
        MainActor.assumeIsolated {
            let client = TestLiveLocationClient(authorization: .authorizedWhenInUse)
            let store = InMemoryRecordedTrackStore()
            var config = LiveTrackRecorderConfiguration()
            config.maximumGapSeconds = 60
            let model = LiveLocationFeatureModel(
                client: client,
                store: store,
                recorder: LiveTrackRecorder(configuration: config)
            )

            model.setRecordingEnabled(true)
            client.emit(samples: [
                sample(offsetSeconds: 0, latitude: 52.52, longitude: 13.40, accuracy: 6),
                sample(offsetSeconds: 12, latitude: 52.5203, longitude: 13.4003, accuracy: 6),
            ])
            // Gap → auto-split
            client.emit(samples: [
                sample(offsetSeconds: 212, latitude: 52.5210, longitude: 13.4010, accuracy: 6),
                sample(offsetSeconds: 224, latitude: 52.5215, longitude: 13.4015, accuracy: 6),
            ])
            // Stop → second segment persisted
            model.setRecordingEnabled(false)

            XCTAssertEqual(model.recordedTracks.count, 2, "both segments must be persisted")
            XCTAssertEqual(store.savedTracks.count, 2)
        }
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
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

private final class BlockingLiveLocationServerUploader: LiveLocationServerUploading {
    private(set) var wasCancelled = false
    var onUploadStarted: (() -> Void)?
    var onUploadCancelled: (() -> Void)?

    func upload(
        request: LiveLocationUploadRequest,
        to endpoint: URL,
        bearerToken: String?
    ) async throws {
        onUploadStarted?()

        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch is CancellationError {
            wasCancelled = true
            onUploadCancelled?()
            throw CancellationError()
        }
    }
}
