import Foundation

// ActivityKit is only available on iOS — guard every ActivityKit-dependent declaration.
#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// ActivityAttributes for the Live Activity / Dynamic Island shown during an active track recording.
@available(iOS 16.1, *)
public struct TrackingAttributes: ActivityAttributes {
    public typealias ContentState = TrackingStatus

    /// Static data — does not change while the Activity is live.
    public let trackName: String
    public let startTime: Date

    public init(trackName: String, startTime: Date) {
        self.trackName = trackName
        self.startTime = startTime
    }
}
#endif

/// Dynamic state of the Live Activity — updated as the recording progresses.
/// Declared outside the ActivityKit guard so it is available for unit tests on all platforms.
public struct TrackingStatus: Codable, Hashable, Sendable {
    /// Whether the recording is currently active.
    public var isRecording: Bool
    /// Accumulated distance in metres.
    public var distanceMeters: Double
    /// Number of recorded track points.
    public var pointCount: Int
    /// Whether recording is currently paused (e.g. upload paused or user-initiated pause).
    public var isPaused: Bool
    /// Number of points waiting to be uploaded. 0 when no upload is configured.
    public var uploadQueueCount: Int
    /// Whether the last upload attempt succeeded. nil = no attempt yet.
    public var lastUploadSuccess: Bool?

    public init(
        isRecording: Bool,
        distanceMeters: Double,
        pointCount: Int,
        isPaused: Bool = false,
        uploadQueueCount: Int = 0,
        lastUploadSuccess: Bool? = nil
    ) {
        self.isRecording = isRecording
        self.distanceMeters = distanceMeters
        self.pointCount = pointCount
        self.isPaused = isPaused
        self.uploadQueueCount = uploadQueueCount
        self.lastUploadSuccess = lastUploadSuccess
    }

    // Custom decoder so older JSON payloads (missing new fields) decode gracefully.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isRecording = try container.decode(Bool.self, forKey: .isRecording)
        distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        isPaused = (try container.decodeIfPresent(Bool.self, forKey: .isPaused)) ?? false
        uploadQueueCount = (try container.decodeIfPresent(Int.self, forKey: .uploadQueueCount)) ?? 0
        lastUploadSuccess = try container.decodeIfPresent(Bool.self, forKey: .lastUploadSuccess)
    }

    /// Human-readable distance string (e.g. "1.2 km" or "850 m").
    public var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        } else {
            return String(format: "%.0f m", max(0, distanceMeters))
        }
    }
}
