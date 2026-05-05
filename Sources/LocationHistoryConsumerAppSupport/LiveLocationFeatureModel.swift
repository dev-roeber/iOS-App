import Foundation
#if canImport(Combine)
import Combine
#endif

@MainActor
public final class LiveLocationFeatureModel: ObservableObject {
    private enum RecordingStartState: Equatable {
        case idle
        case requestingWhenInUse
        case awaitingAlwaysUpgrade
        case readyToStart
        case recording
        case failedAuthorization
    }

    @Published public private(set) var authorization: LiveLocationAuthorization
    @Published public private(set) var isRecording = false
    @Published public private(set) var isAwaitingAuthorization = false
    @Published public private(set) var currentLocation: LiveLocationSample?
    @Published public private(set) var liveTrackPoints: [RecordedTrackPoint] = []
    @Published public private(set) var recordedTracks: [RecordedTrack] = []
    @Published public private(set) var persistenceErrorMessage: String?
    @Published public private(set) var prefersBackgroundTracking = false
    @Published public private(set) var serverUploadStatusMessage: String?
    @Published public private(set) var isUploadingToServer = false
    @Published public private(set) var pendingUploadPointCount: Int = 0
    @Published public private(set) var isUploadPaused = false
    @Published public private(set) var lastSuccessfulUploadAt: Date?
    @Published public private(set) var lastSuccessfulUploadPointCount: Int?
    @Published public private(set) var lastFailedUploadAt: Date?
    @Published public private(set) var consecutiveUploadFailures = 0
    /// Set to true by a deep link (lh2gpx://live) to request navigation to the Live tab.
    /// Reset to false by the observer after acting on it.
    @Published public var navigateToLiveTabRequested = false

    // MARK: - Follow Mode
    @Published public var isFollowingLocation: Bool = false

    // MARK: - Auto-Resume Foundation
    @Published public private(set) var sessionStartedAt: Date?
    @Published public private(set) var sessionID: UUID?
    @Published public var hasInterruptedSession: Bool = false

    private static let sessionStartedAtKey = "live.session.startedAt"
    private static let sessionIDKey = "live.session.id"

    private let client: LiveLocationClient?
    private let store: RecordedTrackStoring
    private let uploader: LiveLocationServerUploading
    private let defaults: UserDefaults
    private var recorder: LiveTrackRecorder
    private var serverUploadConfiguration = LiveLocationServerUploadConfiguration()
    private var pendingUploadQueue = PendingLiveLocationUploadQueue()
    private var currentRecordingSessionID = UUID()
    private var uploadTask: Task<Void, Never>?
    private var recordingStartState: RecordingStartState = .idle

    public init() {
        self.client = makeDefaultLiveLocationClient()
        self.store = RecordedTrackFileStore()
        self.uploader = HTTPSLiveLocationServerUploader()
        self.recorder = LiveTrackRecorder()
        self.defaults = .standard
        self.authorization = client?.authorization ?? .restricted

        do {
            self.recordedTracks = try store.loadTracks()
        } catch {
            self.recordedTracks = []
            self.persistenceErrorMessage = "Saved live tracks could not be loaded."
        }

        restoreInterruptedSessionState()

        client?.onAuthorizationChange = { [weak self] authorization in
            self?.handleAuthorizationChange(authorization)
        }
        client?.onLocationSamples = { [weak self] samples in
            self?.handleLocationSamples(samples)
        }
    }

    public init(
        client: LiveLocationClient?,
        store: RecordedTrackStoring,
        recorder: LiveTrackRecorder = LiveTrackRecorder(),
        uploader: LiveLocationServerUploading = HTTPSLiveLocationServerUploader(),
        userDefaults: UserDefaults = .standard
    ) {
        self.client = client
        self.store = store
        self.uploader = uploader
        self.recorder = recorder
        self.defaults = userDefaults
        self.authorization = client?.authorization ?? .restricted

        do {
            self.recordedTracks = try store.loadTracks()
        } catch {
            self.recordedTracks = []
            self.persistenceErrorMessage = "Saved live tracks could not be loaded."
        }

        restoreInterruptedSessionState()

        client?.onAuthorizationChange = { [weak self] authorization in
            self?.handleAuthorizationChange(authorization)
        }
        client?.onLocationSamples = { [weak self] samples in
            self?.handleLocationSamples(samples)
        }
    }

    public var canDisplayLiveLocation: Bool {
        authorization.allowsForegroundTracking
    }

    public var liveTrackShouldRender: Bool {
        liveTrackPoints.count >= 2
    }

    public var recorderConfiguration: LiveTrackRecorderConfiguration {
        recorder.configuration
    }

    public var isBackgroundTrackingActive: Bool {
        prefersBackgroundTracking && authorization == .authorizedAlways
    }

    public var needsAlwaysAuthorizationUpgrade: Bool {
        prefersBackgroundTracking && authorization == .authorizedWhenInUse
    }

    public var serverUploadConfigurationState: LiveLocationServerUploadConfiguration {
        serverUploadConfiguration
    }

    public var hasValidServerUploadConfiguration: Bool {
        serverUploadConfiguration.isEnabled && serverUploadConfiguration.endpointURL != nil
    }

    public var canFlushPendingUploads: Bool {
        hasValidServerUploadConfiguration && !pendingUploadQueue.isEmpty && !isUploadingToServer
    }

    public var canPauseUploads: Bool {
        hasValidServerUploadConfiguration
    }

    public var hasBearerTokenConfigured: Bool {
        serverUploadConfiguration.trimmedBearerToken != nil
    }

    public var uploadQueueLimit: Int {
        10_000
    }

    public var uploadStatusSummary: String {
        guard serverUploadConfiguration.isEnabled else {
            return "Disabled"
        }
        guard serverUploadConfiguration.endpointURL != nil else {
            return "Invalid endpoint"
        }
        if isUploadingToServer {
            return "Uploading"
        }
        if isUploadPaused {
            return "Paused"
        }
        if consecutiveUploadFailures > 0 {
            return "Needs retry"
        }
        if pendingUploadPointCount > 0 {
            return "Queue pending"
        }
        return "Ready"
    }

    public var uploadAssistiveMessage: String? {
        guard serverUploadConfiguration.isEnabled else { return nil }
        if serverUploadConfiguration.endpointURL == nil {
            return "Server upload is enabled, but the URL is invalid."
        }
        if isUploadPaused {
            return pendingUploadQueue.isEmpty
                ? "Uploads are paused until you resume them."
                : "Uploads are paused. Resume or flush manually to send queued points."
        }
        if consecutiveUploadFailures > 0 {
            return "Retry runs on the next accepted point, or you can flush the queue manually."
        }
        if pendingUploadQueue.isEmpty {
            return hasBearerTokenConfigured
                ? "Server upload is ready."
                : "Server upload is ready. No bearer token is configured."
        }
        return "Queued points wait until the configured batch size is reached."
    }

    public var permissionTitle: String {
        switch authorization {
        case .notDetermined:
            return isAwaitingAuthorization ? "Waiting for Location Permission" : "Location Permission Not Requested"
        case .restricted:
            return "Location Access Restricted"
        case .denied:
            return "Location Access Denied"
        case .authorizedWhenInUse, .authorizedAlways:
            if recordingStartState == .failedAuthorization,
               prefersBackgroundTracking,
               authorization == .authorizedWhenInUse {
                return "Background Access Required"
            }
            if isRecording && isBackgroundTrackingActive {
                return "Recording in Background"
            }
            if needsAlwaysAuthorizationUpgrade {
                return "Background Upgrade Pending"
            }
            return isRecording ? "Recording Live Track" : "Live Location Ready"
        }
    }

    public var permissionMessage: String {
        if let persistenceErrorMessage {
            return persistenceErrorMessage
        }

        switch authorization {
        case .notDetermined:
            return isAwaitingAuthorization
                ? "Approve while-using-the-app access to show your position and start recording."
                : "Turn on live location to request foreground-only access."
        case .restricted:
            return "Location services are restricted on this device. Live recording stays unavailable."
        case .denied:
            return "Enable While Using the App access in Settings to show your position and record live tracks."
        case .authorizedWhenInUse, .authorizedAlways:
            if recordingStartState == .failedAuthorization,
               prefersBackgroundTracking,
               authorization == .authorizedWhenInUse {
                return "Recording did not start because Apple has not granted Always Allow yet. Enable Always in Settings or turn off background recording in Options."
            }
            if needsAlwaysAuthorizationUpgrade {
                return "Background recording is enabled in Options, but Apple has only granted While Using the App so far. Approve Always Allow to keep recording when the app leaves the foreground."
            }
            if isRecording {
                if isBackgroundTrackingActive {
                    return "Recording can continue in the background and stays local to this app until you stop."
                }
                if liveTrackPoints.isEmpty {
                    return "Waiting for accurate foreground location updates."
                }
                return "Recording stays local to this app and is saved only when you stop."
            }
            if prefersBackgroundTracking {
                return "Location is ready. Start recording to capture a live track and keep it running in the background when Always Allow is active."
            }
            return "Foreground location is authorized. Start recording to show your position and begin a new live track."
        }
    }

    public func setRecordingEnabled(_ enabled: Bool) {
        if enabled {
            startRecordingFlow()
        } else {
            stopRecordingFlow()
        }
    }

    public func refreshAuthorization() {
        authorization = client?.authorization ?? .restricted
    }

    public func updateRecordedTrack(_ track: RecordedTrack) {
        var updatedTracks = recordedTracks
        guard let index = updatedTracks.firstIndex(where: { $0.id == track.id }) else {
            return
        }

        updatedTracks[index] = track
        persistRecordedTracks(updatedTracks)
    }

    public func deleteRecordedTrack(id: UUID) {
        let updatedTracks = recordedTracks.filter { $0.id != id }
        guard updatedTracks.count != recordedTracks.count else {
            return
        }

        persistRecordedTracks(updatedTracks)
    }

    public func updateRecorderConfiguration(_ configuration: LiveTrackRecorderConfiguration) {
        recorder.updateConfiguration(configuration)
    }

    public func setBackgroundTrackingPreference(_ enabled: Bool) {
        prefersBackgroundTracking = enabled
        if isRecording {
            applyBackgroundTrackingConfiguration()
        }

        if enabled,
           authorization == .authorizedWhenInUse,
           recordingStartState != .awaitingAlwaysUpgrade {
            client?.requestAlwaysAuthorization()
        }

        if !enabled,
           recordingStartState == .awaitingAlwaysUpgrade,
           authorization.allowsForegroundTracking {
            transition(to: .readyToStart)
            beginRecording()
        }
    }

    public func setServerUploadConfiguration(_ configuration: LiveLocationServerUploadConfiguration) {
        let previousConfiguration = serverUploadConfiguration
        serverUploadConfiguration = configuration

        if previousConfiguration != configuration {
            cancelInFlightUpload(reason: nil)
        }

        if !configuration.isEnabled {
            pendingUploadQueue.removeAll()
            pendingUploadPointCount = 0
            isUploadPaused = false
            serverUploadStatusMessage = nil
            syncLiveActivityState()
            return
        }

        guard configuration.endpointURL != nil else {
            isUploadingToServer = false
            serverUploadStatusMessage = "Server upload is enabled, but the URL is invalid."
            syncLiveActivityState()
            return
        }

        if pendingUploadQueue.isEmpty {
            serverUploadStatusMessage = "Server upload ready for \(configuration.endpointDisplayName)."
        }
        schedulePendingUploadIfNeeded()
        syncLiveActivityState()
    }

    public func setUploadPaused(_ paused: Bool) {
        guard hasValidServerUploadConfiguration else { return }
        isUploadPaused = paused
        if paused {
            serverUploadStatusMessage = "Server upload paused."
            syncLiveActivityState()
            return
        }

        if pendingUploadQueue.isEmpty {
            serverUploadStatusMessage = "Server upload ready for \(serverUploadConfiguration.endpointDisplayName)."
        } else {
            let queuedPointCount = pendingUploadQueue.count
            serverUploadStatusMessage = "Upload resumed with \(queuedPointCount) queued point\(queuedPointCount == 1 ? "" : "s")."
            schedulePendingUploadIfNeeded()
        }
        syncLiveActivityState()
    }

    public func flushPendingUploads() {
        guard serverUploadConfiguration.isEnabled else { return }
        guard let endpoint = serverUploadConfiguration.endpointURL else {
            serverUploadStatusMessage = "Server upload is enabled, but the URL is invalid."
            return
        }
        guard !pendingUploadQueue.isEmpty else {
            serverUploadStatusMessage = "No queued points to upload."
            return
        }
        guard !isUploadingToServer else { return }

        schedulePendingUploadIfNeeded(force: true, endpointOverride: endpoint)
    }

    public func dismissInterruptedSession() {
        clearPersistedSessionState()
    }

    private func startRecordingFlow() {
        guard recordingStartState == .idle || recordingStartState == .failedAuthorization else {
            return
        }

        persistenceErrorMessage = nil
        currentRecordingSessionID = UUID()
        pendingUploadQueue.removeAll()
        pendingUploadPointCount = 0

        hasInterruptedSession = false
        if serverUploadConfiguration.isEnabled, serverUploadConfiguration.endpointURL != nil {
            serverUploadStatusMessage = "Server upload ready for \(serverUploadConfiguration.endpointDisplayName)."
        }

        guard let client else {
            authorization = .restricted
            clearPersistedSessionState()
            transition(to: .failedAuthorization)
            return
        }

        authorization = client.authorization

        switch authorization {
        case .authorizedAlways:
            transition(to: .readyToStart)
            beginRecording()
        case .authorizedWhenInUse:
            applyBackgroundTrackingConfiguration()
            if prefersBackgroundTracking {
                // Background recording must not start until the Always upgrade has resolved.
                transition(to: .awaitingAlwaysUpgrade)
                client.requestAlwaysAuthorization()
            } else {
                transition(to: .readyToStart)
                beginRecording()
            }
        case .notDetermined:
            transition(to: .requestingWhenInUse)
            client.requestWhenInUseAuthorization()
        case .restricted, .denied:
            clearPersistedSessionState()
            transition(to: .failedAuthorization)
        }
    }

    private func stopRecordingFlow() {
        transition(to: .idle)
        client?.stopUpdatingLocation()
        currentLocation = nil
        isFollowingLocation = false
        schedulePendingUploadIfNeeded()
        pendingUploadPointCount = pendingUploadQueue.count

        clearPersistedSessionState()

        #if os(iOS)
        if #available(iOS 16.1, *) {
            ActivityManager.shared.endActivity(
                distanceMeters: recorder.accumulatedDistanceM,
                pointCount: recorder.points.count,
                isPaused: isUploadPaused,
                uploadQueueCount: pendingUploadQueue.count,
                lastUploadSuccess: liveActivityLastUploadSuccess,
                uploadState: liveActivityUploadState
            )
        }
        #endif

        let finishedTrack = recorder.stop()
        liveTrackPoints = []

        guard let finishedTrack else {
            return
        }

        let persistedTrack = RecordedTrack(
            id: finishedTrack.id,
            startedAt: finishedTrack.startedAt,
            endedAt: finishedTrack.endedAt,
            dayKey: finishedTrack.dayKey,
            distanceM: finishedTrack.distanceM,
            captureMode: isBackgroundTrackingActive ? .backgroundAlways : .foregroundWhileInUse,
            points: finishedTrack.points
        )

        var updatedTracks = recordedTracks
        updatedTracks.insert(persistedTrack, at: 0)
        persistRecordedTracks(updatedTracks)
        updateWidgetData(newTrack: persistedTrack, allTracks: updatedTracks)
    }

    private func handleAuthorizationChange(_ authorization: LiveLocationAuthorization) {
        self.authorization = authorization
        if recordingStartState == .recording {
            applyBackgroundTrackingConfiguration()
            if !authorization.allowsForegroundTracking {
                transition(to: .failedAuthorization)
                client?.stopUpdatingLocation()
            }
        }

        switch recordingStartState {
        case .requestingWhenInUse:
            resolveForegroundAuthorizationRequest(using: authorization)
        case .awaitingAlwaysUpgrade:
            resolveAlwaysAuthorizationUpgrade(using: authorization)
        case .idle, .readyToStart, .recording, .failedAuthorization:
            break
        }
    }

    private func resolveForegroundAuthorizationRequest(using authorization: LiveLocationAuthorization) {
        switch authorization {
        case .authorizedAlways:
            transition(to: .readyToStart)
            beginRecording()
        case .authorizedWhenInUse:
            if prefersBackgroundTracking {
                transition(to: .awaitingAlwaysUpgrade)
                client?.requestAlwaysAuthorization()
            } else {
                transition(to: .readyToStart)
                beginRecording()
            }
        case .notDetermined:
            break
        case .restricted, .denied:
            clearPersistedSessionState()
            transition(to: .failedAuthorization)
        }
    }

    private func resolveAlwaysAuthorizationUpgrade(using authorization: LiveLocationAuthorization) {
        switch authorization {
        case .authorizedAlways:
            transition(to: .readyToStart)
            beginRecording()
        case .authorizedWhenInUse, .restricted, .denied:
            clearPersistedSessionState()
            transition(to: .failedAuthorization)
        case .notDetermined:
            break
        }
    }

    private func beginRecording() {
        guard recordingStartState == .readyToStart else {
            return
        }

        applyBackgroundTrackingConfiguration()
        recorder.start()
        persistInterruptedSessionState(
            startedAt: recorder.points.first?.timestamp ?? Date(),
            sessionID: currentRecordingSessionID
        )
        liveTrackPoints = []
        transition(to: .recording)
        client?.startUpdatingLocation()

        #if os(iOS)
        if #available(iOS 16.1, *) {
            let trackName = "Live Track \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
            ActivityManager.shared.startActivity(trackName: trackName, startTime: Date())
        }
        #endif
    }

    private func handleLocationSamples(_ samples: [LiveLocationSample]) {
        guard isRecording else {
            return
        }

        guard let bestSample = samples.last(where: isDisplayQuality) ?? samples.last else {
            return
        }

        if isDisplayQuality(bestSample) {
            currentLocation = bestSample
        }

        var recorder = self.recorder
        var acceptedPoints: [RecordedTrackPoint] = []
        for sample in samples {
            if recorder.append(sample), let point = recorder.points.last {
                acceptedPoints.append(point)
            }
        }
        self.recorder = recorder

        // Drain any track that was auto-split due to a gap exceeding maximumGapSeconds.
        if let splitTrack = self.recorder.takeSplitOffTrack() {
            let captureMode: RecordedTrackCaptureMode = isBackgroundTrackingActive ? .backgroundAlways : .foregroundWhileInUse
            let corrected = RecordedTrack(
                id: splitTrack.id,
                startedAt: splitTrack.startedAt,
                endedAt: splitTrack.endedAt,
                dayKey: splitTrack.dayKey,
                distanceM: splitTrack.distanceM,
                captureMode: captureMode,
                points: splitTrack.points
            )
            var updated = recordedTracks
            updated.insert(corrected, at: 0)
            persistRecordedTracks(updated)
            updateWidgetData(newTrack: corrected, allTracks: updated)
            currentRecordingSessionID = UUID()
            liveTrackPoints = self.recorder.points
        }

        if !acceptedPoints.isEmpty {
            liveTrackPoints = self.recorder.points
            enqueueUpload(points: acceptedPoints)

            #if os(iOS)
            if #available(iOS 16.1, *) {
                syncLiveActivityState()
            }
            #endif
        }
    }

    private func isDisplayQuality(_ sample: LiveLocationSample) -> Bool {
        sample.horizontalAccuracyM > 0 && sample.horizontalAccuracyM <= 100
    }

    private func persistRecordedTracks(_ tracks: [RecordedTrack]) {
        do {
            try store.saveTracks(tracks)
            recordedTracks = tracks.sorted { $0.startedAt > $1.startedAt }
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = "Live track changes could not be saved."
        }
    }

    private func applyBackgroundTrackingConfiguration() {
        client?.setBackgroundTrackingEnabled(prefersBackgroundTracking && authorization == .authorizedAlways)
    }

    private func restoreInterruptedSessionState() {
        guard
            let rawSessionID = defaults.string(forKey: Self.sessionIDKey),
            let restoredSessionID = UUID(uuidString: rawSessionID),
            defaults.object(forKey: Self.sessionStartedAtKey) != nil
        else {
            clearPersistedSessionState()
            return
        }

        let timestamp = defaults.double(forKey: Self.sessionStartedAtKey)
        guard timestamp > 0 else {
            clearPersistedSessionState()
            return
        }

        sessionID = restoredSessionID
        sessionStartedAt = Date(timeIntervalSince1970: timestamp)
        hasInterruptedSession = true
    }

    private func persistInterruptedSessionState(startedAt: Date, sessionID: UUID) {
        sessionStartedAt = startedAt
        self.sessionID = sessionID
        hasInterruptedSession = false
        defaults.set(startedAt.timeIntervalSince1970, forKey: Self.sessionStartedAtKey)
        defaults.set(sessionID.uuidString, forKey: Self.sessionIDKey)
    }

    private func clearPersistedSessionState() {
        sessionStartedAt = nil
        sessionID = nil
        hasInterruptedSession = false
        defaults.removeObject(forKey: Self.sessionStartedAtKey)
        defaults.removeObject(forKey: Self.sessionIDKey)
    }

    private func transition(to state: RecordingStartState) {
        recordingStartState = state
        isAwaitingAuthorization = state == .requestingWhenInUse || state == .awaitingAlwaysUpgrade
        isRecording = state == .recording
    }

    private func enqueueUpload(points: [RecordedTrackPoint]) {
        guard !points.isEmpty else {
            return
        }

        pendingUploadQueue.enqueue(contentsOf: points.map {
            LiveLocationUploadPoint(
                latitude: $0.latitude,
                longitude: $0.longitude,
                timestamp: $0.timestamp,
                horizontalAccuracyM: $0.horizontalAccuracyM
            )
        })
        pendingUploadQueue.trimToLast(uploadQueueLimit)
        pendingUploadPointCount = pendingUploadQueue.count
        schedulePendingUploadIfNeeded()
        syncLiveActivityState()
    }

    private func schedulePendingUploadIfNeeded(
        force: Bool = false,
        endpointOverride: URL? = nil
    ) {
        guard !isUploadingToServer, uploadTask == nil else {
            return
        }
        guard serverUploadConfiguration.isEnabled else {
            return
        }
        guard let endpoint = endpointOverride ?? serverUploadConfiguration.endpointURL else {
            serverUploadStatusMessage = "Server upload is enabled, but the URL is invalid."
            return
        }
        guard force || !isUploadPaused else {
            return
        }
        guard !pendingUploadQueue.isEmpty else {
            return
        }
        guard force || pendingUploadQueue.count >= serverUploadConfiguration.minimumBatchSize || !isRecording else {
            return
        }

        isUploadingToServer = true
        let points = pendingUploadQueue.snapshot()
        let request = LiveLocationUploadRequest(
            source: "LocationHistory2GPX-iOS",
            sessionID: currentRecordingSessionID,
            captureMode: activeCaptureMode.rawValue,
            sentAt: Date(),
            points: points
        )
        let endpointDisplayName = serverUploadConfiguration.endpointDisplayName
        let bearerToken = serverUploadConfiguration.trimmedBearerToken
        serverUploadStatusMessage = "Uploading \(points.count) point\(points.count == 1 ? "" : "s") to \(endpointDisplayName)."

        uploadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.uploader.upload(
                    request: request,
                    to: endpoint,
                    bearerToken: bearerToken
                )
                try Task.checkCancellation()
                self.handleUploadSuccess(sentPointCount: points.count, endpointDisplayName: endpointDisplayName)
            } catch is CancellationError {
                self.handleUploadCancellation()
            } catch {
                self.handleUploadFailure(error)
            }
        }
    }

    private func handleUploadSuccess(sentPointCount: Int, endpointDisplayName: String) {
        uploadTask = nil
        pendingUploadQueue.dropFirst(sentPointCount)
        pendingUploadPointCount = pendingUploadQueue.count
        isUploadingToServer = false
        lastSuccessfulUploadAt = Date()
        lastSuccessfulUploadPointCount = sentPointCount
        consecutiveUploadFailures = 0
        serverUploadStatusMessage = "Last upload sent \(sentPointCount) point\(sentPointCount == 1 ? "" : "s") to \(endpointDisplayName)."

        if !pendingUploadQueue.isEmpty {
            schedulePendingUploadIfNeeded()
        }
        syncLiveActivityState()
    }

    private func handleUploadFailure(_ error: Error) {
        uploadTask = nil
        isUploadingToServer = false
        lastFailedUploadAt = Date()
        consecutiveUploadFailures += 1
        serverUploadStatusMessage = "Server upload failed: \(error.localizedDescription)"
        syncLiveActivityState()
    }

    private func handleUploadCancellation() {
        uploadTask = nil
        isUploadingToServer = false
        if serverUploadConfiguration.isEnabled, serverUploadConfiguration.endpointURL != nil {
            if pendingUploadQueue.isEmpty {
                serverUploadStatusMessage = "Server upload ready for \(serverUploadConfiguration.endpointDisplayName)."
            } else if isUploadPaused {
                serverUploadStatusMessage = "Server upload paused."
            } else {
                serverUploadStatusMessage = "Upload cancelled. Queued points stay ready for retry."
            }
        }
        syncLiveActivityState()
    }

    private func cancelInFlightUpload(reason: String?) {
        uploadTask?.cancel()
        uploadTask = nil
        isUploadingToServer = false
        if let reason {
            serverUploadStatusMessage = reason
        }
        syncLiveActivityState()
    }

    private var liveActivityUploadState: LiveActivityUploadState {
        guard serverUploadConfiguration.isEnabled, serverUploadConfiguration.endpointURL != nil else {
            return .disabled
        }
        if isUploadPaused {
            return .paused
        }
        if isUploadingToServer {
            return .active
        }
        if consecutiveUploadFailures > 0 {
            return .failed
        }
        if pendingUploadPointCount > 0 {
            return .pending
        }
        return .active
    }

    private var liveActivityLastUploadSuccess: Bool? {
        if consecutiveUploadFailures > 0 {
            return false
        }
        if lastSuccessfulUploadAt != nil {
            return true
        }
        return nil
    }

    private func syncLiveActivityState() {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            guard isRecording else { return }
            ActivityManager.shared.updateActivity(
                distanceMeters: recorder.accumulatedDistanceM,
                pointCount: recorder.points.count,
                isPaused: isUploadPaused,
                uploadQueueCount: pendingUploadPointCount,
                lastUploadSuccess: liveActivityLastUploadSuccess,
                uploadState: liveActivityUploadState
            )
        }
        #endif
    }

    private var activeCaptureMode: RecordedTrackCaptureMode {
        isBackgroundTrackingActive ? .backgroundAlways : .foregroundWhileInUse
    }

    private func updateWidgetData(newTrack: RecordedTrack, allTracks: [RecordedTrack]) {
        let recording = WidgetDataStore.LastRecording(
            date: newTrack.endedAt,
            distanceMeters: newTrack.distanceM,
            durationSeconds: newTrack.endedAt.timeIntervalSince(newTrack.startedAt),
            trackName: newTrack.dayKey
        )
        WidgetDataStore.save(recording: recording)

        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekTracks = allTracks.filter { $0.startedAt >= startOfWeek }
        let weeklyKm = weekTracks.reduce(0.0) { $0 + $1.distanceM } / 1000
        WidgetDataStore.saveWeeklyStats(totalKm: weeklyKm, routeCount: weekTracks.count)
    }
}

private struct PendingLiveLocationUploadQueue {
    private var storage: [LiveLocationUploadPoint] = []
    private var headIndex = 0

    var count: Int {
        max(0, storage.count - headIndex)
    }

    var isEmpty: Bool {
        count == 0
    }

    mutating func enqueue(contentsOf points: [LiveLocationUploadPoint]) {
        guard !points.isEmpty else {
            return
        }
        storage.append(contentsOf: points)
    }

    mutating func dropFirst(_ count: Int) {
        guard count > 0, !isEmpty else {
            return
        }

        if count >= self.count {
            removeAll()
            return
        }

        headIndex += count
        compactIfNeeded()
    }

    mutating func trimToLast(_ limit: Int) {
        guard limit >= 0 else {
            return
        }

        let overflow = count - limit
        guard overflow > 0 else {
            return
        }

        dropFirst(overflow)
    }

    func snapshot() -> [LiveLocationUploadPoint] {
        guard headIndex < storage.count else {
            return []
        }
        return Array(storage[headIndex...])
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        headIndex = 0
    }

    private mutating func compactIfNeeded() {
        guard headIndex > 1024, headIndex * 2 >= storage.count else {
            return
        }

        storage.removeFirst(headIndex)
        headIndex = 0
    }
}

@MainActor
private func makeDefaultLiveLocationClient() -> LiveLocationClient? {
    #if canImport(CoreLocation)
    return SystemLiveLocationClient()
    #else
    return nil
    #endif
}
