import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Manages the Live Activity shown during active track recordings.
public final class ActivityManager {
    public static let shared = ActivityManager()

    #if canImport(ActivityKit) && os(iOS)
    // Stored as Any? to avoid '@available' on stored property (not supported by Swift).
    // Cast to Activity<TrackingAttributes> at each use site after #available check.
    private var _currentActivityBox: Any?
    #endif

    private init() {}

    /// Starts a new Live Activity for a recording session.
    public func startActivity(trackName: String, startTime: Date) {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.2, *) {
            _startActivityInternal(trackName: trackName, startTime: startTime)
        }
        #endif
    }

    /// Pushes a state update to the current Live Activity.
    public func updateActivity(distanceMeters: Double, pointCount: Int) {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.2, *) {
            _updateActivityInternal(distanceMeters: distanceMeters, pointCount: pointCount)
        }
        #endif
    }

    /// Ends the current Live Activity with a final state snapshot.
    public func endActivity(distanceMeters: Double, pointCount: Int) {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.2, *) {
            _endActivityInternal(distanceMeters: distanceMeters, pointCount: pointCount)
        }
        #endif
    }

    /// Immediately dismisses all live Activities — call on app launch to clean up stale sessions.
    public func cancelAllActivities() {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.2, *) {
            _cancelAllActivitiesInternal()
        }
        #endif
    }

    // MARK: - Private iOS 16.2+ helpers

    #if canImport(ActivityKit) && os(iOS)
    @available(iOS 16.2, *)
    private func _startActivityInternal(trackName: String, startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TrackingAttributes(trackName: trackName, startTime: startTime)
        let initialState = TrackingStatus(isRecording: true, distanceMeters: 0, pointCount: 0)
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            _currentActivityBox = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // ActivityKit unavailable or permission denied — fail silently.
        }
    }

    @available(iOS 16.2, *)
    private func _updateActivityInternal(distanceMeters: Double, pointCount: Int) {
        guard let activity = _currentActivityBox as? Activity<TrackingAttributes> else { return }

        let updatedState = TrackingStatus(
            isRecording: true,
            distanceMeters: distanceMeters,
            pointCount: pointCount
        )
        let updatedContent = ActivityContent(state: updatedState, staleDate: nil)

        Task {
            await activity.update(updatedContent)
        }
    }

    @available(iOS 16.2, *)
    private func _endActivityInternal(distanceMeters: Double, pointCount: Int) {
        guard let activity = _currentActivityBox as? Activity<TrackingAttributes> else { return }

        let finalState = TrackingStatus(
            isRecording: false,
            distanceMeters: distanceMeters,
            pointCount: pointCount
        )
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: Date().addingTimeInterval(5)
        )

        Task {
            await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(5)))
            self._currentActivityBox = nil
        }
    }

    @available(iOS 16.2, *)
    private func _cancelAllActivitiesInternal() {
        Task {
            for activity in Activity<TrackingAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self._currentActivityBox = nil
        }
    }
    #endif
}
