import Foundation

/// Provenance/origin marker for a `DaySummary`. The vast majority of summaries
/// originate from imported location history files (`.imported`). LiveTracks
/// recorded on-device are surfaced into the same day list via dedicated kinds
/// so the UI can decorate them with a live indicator without diverging the
/// list rendering pipeline.
public enum DaySummaryKind: Equatable, Sendable {
    /// Day summary derived from imported history (the default for all legacy
    /// callers).
    case imported
    /// Live recording that is still actively capturing points.
    case live
    /// LiveTrack that has finished recording but is still surfaced as a live
    /// entry distinct from imported history.
    case liveCompleted
}

public struct DaySummary: Equatable {
    public let date: String
    public let visitCount: Int
    public let activityCount: Int
    public let pathCount: Int
    public let totalPathPointCount: Int
    public let totalPathDistanceM: Double
    public let hasContent: Bool
    public let exportablePathCount: Int
    public let firstEntryStartTime: String?
    public let lastEntryEndTime: String?
    public let kind: DaySummaryKind

    public init(
        date: String,
        visitCount: Int,
        activityCount: Int,
        pathCount: Int,
        totalPathPointCount: Int,
        totalPathDistanceM: Double,
        hasContent: Bool,
        exportablePathCount: Int? = nil,
        firstEntryStartTime: String? = nil,
        lastEntryEndTime: String? = nil,
        kind: DaySummaryKind = .imported
    ) {
        self.date = date
        self.visitCount = visitCount
        self.activityCount = activityCount
        self.pathCount = pathCount
        self.totalPathPointCount = totalPathPointCount
        self.totalPathDistanceM = totalPathDistanceM
        self.hasContent = hasContent
        self.exportablePathCount = exportablePathCount ?? pathCount
        self.firstEntryStartTime = firstEntryStartTime
        self.lastEntryEndTime = lastEntryEndTime
        self.kind = kind
    }
}
