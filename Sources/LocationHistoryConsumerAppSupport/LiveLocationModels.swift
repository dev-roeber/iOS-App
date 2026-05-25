import Foundation

public enum LiveLocationAuthorization: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    public var allowsForegroundTracking: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined, .restricted, .denied:
            return false
        }
    }
}

public struct LiveLocationSample: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    public let horizontalAccuracyM: Double
    /// Altitude in metres above mean sea level — only populated when the
    /// device reported a positive `verticalAccuracy`. Train 9.2.
    public let altitudeM: Double?
    /// Vertical accuracy in metres. `nil` (or `<= 0`) means the altitude
    /// reading is not trustworthy and must not be surfaced to the user
    /// or exported to GPX. Train 9.2.
    public let verticalAccuracyM: Double?

    public init(
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        horizontalAccuracyM: Double,
        altitudeM: Double? = nil,
        verticalAccuracyM: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracyM = horizontalAccuracyM
        self.altitudeM = altitudeM
        self.verticalAccuracyM = verticalAccuracyM
    }
}

public struct RecordedTrackPoint: Codable, Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    public let horizontalAccuracyM: Double
    /// Altitude in metres above mean sea level. Optional + backward-
    /// compatible via `decodeIfPresent` — JSON files written before Train
    /// 9.2 continue to decode cleanly with `altitudeM = nil`. Only set
    /// when the underlying CoreLocation reading had a positive
    /// `verticalAccuracy`.
    public let altitudeM: Double?
    /// Vertical accuracy in metres associated with `altitudeM`.
    public let verticalAccuracyM: Double?

    public init(
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        horizontalAccuracyM: Double,
        altitudeM: Double? = nil,
        verticalAccuracyM: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracyM = horizontalAccuracyM
        self.altitudeM = altitudeM
        self.verticalAccuracyM = verticalAccuracyM
    }

    // MARK: - Codable (backward-compatible with pre-9.2 JSON)
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, timestamp, horizontalAccuracyM
        case altitudeM, verticalAccuracyM
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        horizontalAccuracyM = try container.decode(Double.self, forKey: .horizontalAccuracyM)
        altitudeM = try container.decodeIfPresent(Double.self, forKey: .altitudeM)
        verticalAccuracyM = try container.decodeIfPresent(Double.self, forKey: .verticalAccuracyM)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(horizontalAccuracyM, forKey: .horizontalAccuracyM)
        try container.encodeIfPresent(altitudeM, forKey: .altitudeM)
        try container.encodeIfPresent(verticalAccuracyM, forKey: .verticalAccuracyM)
    }
}

public enum RecordedTrackCaptureMode: String, Codable, Equatable, Hashable {
    case foregroundWhileInUse
    case backgroundAlways
}

public struct RecordedTrack: Codable, Equatable, Identifiable, Hashable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let dayKey: String
    public let distanceM: Double
    public let captureMode: RecordedTrackCaptureMode
    public let points: [RecordedTrackPoint]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        dayKey: String,
        distanceM: Double,
        captureMode: RecordedTrackCaptureMode,
        points: [RecordedTrackPoint]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.dayKey = dayKey
        self.distanceM = distanceM
        self.captureMode = captureMode
        self.points = points
    }

    public var pointCount: Int {
        points.count
    }
}
