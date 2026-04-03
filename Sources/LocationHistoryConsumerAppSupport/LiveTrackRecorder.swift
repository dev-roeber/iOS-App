import Foundation

public struct LiveTrackRecorderConfiguration: Equatable {
    public var maximumAcceptedAccuracyM: Double
    public var duplicateDistanceThresholdM: Double
    public var minimumDistanceDeltaM: Double
    public var minimumTimeDeltaS: TimeInterval
    public var minimumPersistedPointCount: Int
    /// Absolute minimum elapsed time between any two accepted points.
    /// A value of 0 disables the gate (all-pass). Set from `RecordingIntervalPreference.totalSeconds`.
    public var minimumRecordingIntervalS: TimeInterval

    public init(
        maximumAcceptedAccuracyM: Double = 65,
        duplicateDistanceThresholdM: Double = 3,
        minimumDistanceDeltaM: Double = 15,
        minimumTimeDeltaS: TimeInterval = 8,
        minimumPersistedPointCount: Int = 2,
        minimumRecordingIntervalS: TimeInterval = 0
    ) {
        self.maximumAcceptedAccuracyM = maximumAcceptedAccuracyM
        self.duplicateDistanceThresholdM = duplicateDistanceThresholdM
        self.minimumDistanceDeltaM = minimumDistanceDeltaM
        self.minimumTimeDeltaS = minimumTimeDeltaS
        self.minimumPersistedPointCount = minimumPersistedPointCount
        self.minimumRecordingIntervalS = minimumRecordingIntervalS
    }
}

public struct LiveTrackRecorder {
    public private(set) var points: [RecordedTrackPoint] = []
    public private(set) var isRecording = false

    public private(set) var configuration: LiveTrackRecorderConfiguration
    private let calendar: Calendar

    public init(
        configuration: LiveTrackRecorderConfiguration = LiveTrackRecorderConfiguration(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    public mutating func updateConfiguration(_ configuration: LiveTrackRecorderConfiguration) {
        self.configuration = configuration
    }

    public mutating func start() {
        points = []
        isRecording = true
    }

    public mutating func append(_ sample: LiveLocationSample) -> Bool {
        guard isRecording, acceptsAccuracy(sample) else {
            return false
        }

        let candidate = RecordedTrackPoint(
            latitude: sample.latitude,
            longitude: sample.longitude,
            timestamp: sample.timestamp,
            horizontalAccuracyM: sample.horizontalAccuracyM
        )

        guard let last = points.last else {
            points = [candidate]
            return true
        }

        let timeDelta = candidate.timestamp.timeIntervalSince(last.timestamp)
        if timeDelta <= 0 {
            return false
        }

        // Honour the user-configured recording interval: reject if not enough time has elapsed.
        if configuration.minimumRecordingIntervalS > 0,
           timeDelta < configuration.minimumRecordingIntervalS {
            return false
        }

        let distanceDelta = meters(
            fromLatitude: last.latitude,
            fromLongitude: last.longitude,
            toLatitude: candidate.latitude,
            toLongitude: candidate.longitude
        )

        if distanceDelta < configuration.duplicateDistanceThresholdM {
            return false
        }

        if distanceDelta < configuration.minimumDistanceDeltaM,
           timeDelta < configuration.minimumTimeDeltaS {
            return false
        }

        points.append(candidate)
        return true
    }

    public mutating func stop() -> RecordedTrack? {
        defer {
            points = []
            isRecording = false
        }

        guard points.count >= configuration.minimumPersistedPointCount,
              let first = points.first,
              let last = points.last else {
            return nil
        }

        let dayKey = dayFormatter.string(from: first.timestamp)
        return RecordedTrack(
            startedAt: first.timestamp,
            endedAt: last.timestamp,
            dayKey: dayKey,
            distanceM: totalDistance(points: points),
            captureMode: .foregroundWhileInUse,
            points: points
        )
    }

    private func acceptsAccuracy(_ sample: LiveLocationSample) -> Bool {
        sample.horizontalAccuracyM > 0 && sample.horizontalAccuracyM <= configuration.maximumAcceptedAccuracyM
    }

    private func totalDistance(points: [RecordedTrackPoint]) -> Double {
        guard points.count >= 2 else { return 0 }

        var total = 0.0
        for pair in zip(points, points.dropFirst()) {
            total += meters(
                fromLatitude: pair.0.latitude,
                fromLongitude: pair.0.longitude,
                toLatitude: pair.1.latitude,
                toLongitude: pair.1.longitude
            )
        }
        return total
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func meters(
        fromLatitude lat1: Double,
        fromLongitude lon1: Double,
        toLatitude lat2: Double,
        toLongitude lon2: Double
    ) -> Double {
        let earthRadiusM = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }
}
