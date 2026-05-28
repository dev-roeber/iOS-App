import Foundation
import LocationHistoryConsumer

/// Converts on-device `RecordedTrack` instances into `DaySummary` rows so they
/// can be merged into the same list rendering pipeline that displays imported
/// history. The resulting summaries carry `kind = .liveCompleted` (or `.live`
/// for an actively running recording) so the UI can decorate them with a
/// live-indicator chip without splitting the day list.
public enum LiveTrackDaySummaryAdapter {

    /// Maps a single `RecordedTrack` to a `DaySummary`.
    ///
    /// - Parameters:
    ///   - track: the on-device recording to surface as a day entry.
    ///   - isLiveNow: pass `true` when the track is currently being captured
    ///     (i.e. matches `liveLocation.isRecording`). Default `false`.
    public static func daySummary(from track: RecordedTrack, isLiveNow: Bool = false) -> DaySummary {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .autoupdatingCurrent
            return f
        }()
        return DaySummary(
            date: track.dayKey,
            visitCount: 0,
            activityCount: 0,
            pathCount: 1,
            totalPathPointCount: track.points.count,
            totalPathDistanceM: max(0, track.distanceM),
            hasContent: track.distanceM > 0 || !track.points.isEmpty,
            exportablePathCount: 0, // LiveTracks gehen nicht durch den AppExport-Pfad
            firstEntryStartTime: timeFormatter.string(from: track.startedAt),
            lastEntryEndTime: timeFormatter.string(from: track.endedAt),
            kind: isLiveNow ? .live : .liveCompleted
        )
    }

    /// Converts a batch of tracks. Optionally marks the most-recent track as
    /// `.live` when `activeRecordingID` matches.
    public static func daySummaries(
        from tracks: [RecordedTrack],
        activeRecordingID: UUID? = nil
    ) -> [DaySummary] {
        tracks.map { track in
            daySummary(from: track, isLiveNow: track.id == activeRecordingID)
        }
    }
}
