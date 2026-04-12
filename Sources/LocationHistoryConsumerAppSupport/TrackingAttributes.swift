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
public struct TrackingStatus: Codable, Hashable {
    /// Whether the recording is currently active.
    public var isRecording: Bool
    /// Accumulated distance in metres.
    public var distanceMeters: Double
    /// Number of recorded track points.
    public var pointCount: Int

    public init(isRecording: Bool, distanceMeters: Double, pointCount: Int) {
        self.isRecording = isRecording
        self.distanceMeters = distanceMeters
        self.pointCount = pointCount
    }

    /// Human-readable distance string (e.g. "1.2 km" or "850 m").
    public var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        } else {
            return String(format: "%.0f m", distanceMeters)
        }
    }
}
