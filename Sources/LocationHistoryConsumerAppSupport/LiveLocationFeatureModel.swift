import Foundation
#if canImport(Combine)
import Combine
#endif

@MainActor
public final class LiveLocationFeatureModel: ObservableObject {
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

    private let client: LiveLocationClient?
    private let store: RecordedTrackStoring
    private let uploader: LiveLocationServerUploading
    private var recorder: LiveTrackRecorder
    private var serverUploadConfiguration = LiveLocationServerUploadConfiguration()
    private var pendingUploadPoints: [LiveLocationUploadPoint] = []
    private var currentRecordingSessionID = UUID()

    public init() {
        self.client = makeDefaultLiveLocationClient()
        self.store = RecordedTrackFileStore()
        self.uploader = HTTPSLiveLocationServerUploader()
        self.recorder = LiveTrackRecorder()
        self.authorization = client?.authorization ?? .restricted

        do {
            self.recordedTracks = try store.loadTracks()
        } catch {
            self.recordedTracks = []
            self.persistenceErrorMessage = "Saved live tracks could not be loaded."
        }

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
        uploader: LiveLocationServerUploading = HTTPSLiveLocationServerUploader()
    ) {
        self.client = client
        self.store = store
        self.uploader = uploader
        self.recorder = recorder
        self.authorization = client?.authorization ?? .restricted

        do {
            self.recordedTracks = try store.loadTracks()
        } catch {
            self.recordedTracks = []
            self.persistenceErrorMessage = "Saved live tracks could not be loaded."
        }

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

    public var permissionTitle: String {
        switch authorization {
        case .notDetermined:
            return isAwaitingAuthorization ? "Waiting for Location Permission" : "Location Permission Not Requested"
        case .restricted:
            return "Location Access Restricted"
        case .denied:
            return "Location Access Denied"
        case .authorizedWhenInUse, .authorizedAlways:
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

        if enabled, authorization == .authorizedWhenInUse {
            client?.requestAlwaysAuthorization()
        }
    }

    public func setServerUploadConfiguration(_ configuration: LiveLocationServerUploadConfiguration) {
        serverUploadConfiguration = configuration

        if !configuration.isEnabled {
            pendingUploadPoints = []
            pendingUploadPointCount = 0
            isUploadingToServer = false
            serverUploadStatusMessage = nil
            return
        }

        guard configuration.endpointURL != nil else {
            serverUploadStatusMessage = "Server upload is enabled, but the URL is invalid."
            return
        }

        if pendingUploadPoints.isEmpty {
            serverUploadStatusMessage = "Server upload ready for \(configuration.endpointDisplayName)."
        }
        schedulePendingUploadIfNeeded()
    }

    private func startRecordingFlow() {
        persistenceErrorMessage = nil
        currentRecordingSessionID = UUID()
        pendingUploadPoints = []
        pendingUploadPointCount = 0
        if serverUploadConfiguration.isEnabled, serverUploadConfiguration.endpointURL != nil {
            serverUploadStatusMessage = "Server upload ready for \(serverUploadConfiguration.endpointDisplayName)."
        }

        guard let client else {
            authorization = .restricted
            return
        }

        switch client.authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            applyBackgroundTrackingConfiguration()
            if prefersBackgroundTracking, client.authorization == .authorizedWhenInUse {
                client.requestAlwaysAuthorization()
            }
            recorder.start()
            liveTrackPoints = []
            isRecording = true
            isAwaitingAuthorization = false
            client.startUpdatingLocation()
        case .notDetermined:
            isAwaitingAuthorization = true
            client.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isAwaitingAuthorization = false
            isRecording = false
        }
    }

    private func stopRecordingFlow() {
        isAwaitingAuthorization = false
        isRecording = false
        client?.stopUpdatingLocation()
        currentLocation = nil
        schedulePendingUploadIfNeeded()
        pendingUploadPointCount = pendingUploadPoints.count

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
    }

    private func handleAuthorizationChange(_ authorization: LiveLocationAuthorization) {
        self.authorization = authorization
        if isRecording {
            applyBackgroundTrackingConfiguration()
        }

        guard isAwaitingAuthorization else {
            return
        }

        if authorization.allowsForegroundTracking {
            startRecordingFlow()
        } else {
            isAwaitingAuthorization = false
            isRecording = false
        }
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

        if !acceptedPoints.isEmpty {
            liveTrackPoints = recorder.points
            enqueueUpload(points: acceptedPoints)
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

    private func enqueueUpload(points: [RecordedTrackPoint]) {
        guard !points.isEmpty else {
            return
        }

        pendingUploadPoints.append(contentsOf: points.map {
            LiveLocationUploadPoint(
                latitude: $0.latitude,
                longitude: $0.longitude,
                timestamp: $0.timestamp,
                horizontalAccuracyM: $0.horizontalAccuracyM
            )
        })

        // Implement queue limit: discard oldest if we exceed 10,000 points.
        let maxQueueSize = 10_000
        if pendingUploadPoints.count > maxQueueSize {
            let overflow = pendingUploadPoints.count - maxQueueSize
            pendingUploadPoints.removeFirst(overflow)
        }

        pendingUploadPointCount = pendingUploadPoints.count
        schedulePendingUploadIfNeeded()
    }

    private func schedulePendingUploadIfNeeded() {
        guard !isUploadingToServer else {
            return
        }
        guard serverUploadConfiguration.isEnabled else {
            return
        }
        guard let endpoint = serverUploadConfiguration.endpointURL else {
            serverUploadStatusMessage = "Server upload is enabled, but the URL is invalid."
            return
        }
        guard !pendingUploadPoints.isEmpty else {
            return
        }
        guard pendingUploadPoints.count >= serverUploadConfiguration.minimumBatchSize || !isRecording else {
            return
        }

        isUploadingToServer = true
        let points = Array(pendingUploadPoints)
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

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.uploader.upload(
                    request: request,
                    to: endpoint,
                    bearerToken: bearerToken
                )
                self.handleUploadSuccess(sentPointCount: points.count, endpointDisplayName: endpointDisplayName)
            } catch {
                self.handleUploadFailure(error)
            }
        }
    }

    private func handleUploadSuccess(sentPointCount: Int, endpointDisplayName: String) {
        if sentPointCount <= pendingUploadPoints.count {
            pendingUploadPoints.removeFirst(sentPointCount)
        } else {
            pendingUploadPoints.removeAll()
        }
        pendingUploadPointCount = pendingUploadPoints.count

        isUploadingToServer = false
        serverUploadStatusMessage = "Last upload sent \(sentPointCount) point\(sentPointCount == 1 ? "" : "s") to \(endpointDisplayName)."

        if !pendingUploadPoints.isEmpty {
            schedulePendingUploadIfNeeded()
        }
    }

    private func handleUploadFailure(_ error: Error) {
        isUploadingToServer = false
        serverUploadStatusMessage = "Server upload failed: \(error.localizedDescription)"
    }

    private var activeCaptureMode: RecordedTrackCaptureMode {
        isBackgroundTrackingActive ? .backgroundAlways : .foregroundWhileInUse
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
