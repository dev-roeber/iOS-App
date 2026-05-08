@preconcurrency import Foundation

/// Progress snapshot for a `LocalTimelineStore` import (Phase-10A P1-B).
///
/// Foundation-only, value-type, `Sendable`. Carries no location data — only
/// counters, optional byte hints and the current import phase. Producers
/// (importer/writer) emit snapshots via a `LocalTimelineImportProgressSink`
/// callback; consumers (UI/Service) treat each snapshot as the latest
/// observation. Snapshots are throttled by the importer (every N entries +
/// on phase changes) and never streamed per-byte/per-entry.
public struct LocalTimelineImportProgress: Equatable, Sendable {

    public enum Phase: String, Equatable, Sendable {
        case idle
        case preparing
        case sniffing
        case importing
        case finalizing
        case completed
        case cancelled
        case failed
    }

    public var phase: Phase
    public var bytesRead: Int64?
    public var totalBytes: Int64?
    public var entriesProcessed: Int
    public var visitsWritten: Int
    public var activitiesWritten: Int
    public var pathsWritten: Int
    public var skippedEntries: Int
    public var currentDay: String?
    public var startedAt: Date
    public var updatedAt: Date
    public var isCancellable: Bool

    public init(
        phase: Phase = .idle,
        bytesRead: Int64? = nil,
        totalBytes: Int64? = nil,
        entriesProcessed: Int = 0,
        visitsWritten: Int = 0,
        activitiesWritten: Int = 0,
        pathsWritten: Int = 0,
        skippedEntries: Int = 0,
        currentDay: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        isCancellable: Bool = false
    ) {
        self.phase = phase
        self.bytesRead = bytesRead
        self.totalBytes = totalBytes
        self.entriesProcessed = entriesProcessed
        self.visitsWritten = visitsWritten
        self.activitiesWritten = activitiesWritten
        self.pathsWritten = pathsWritten
        self.skippedEntries = skippedEntries
        self.currentDay = currentDay
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.isCancellable = isCancellable
    }

    public static func initial(startedAt: Date = Date()) -> LocalTimelineImportProgress {
        LocalTimelineImportProgress(
            phase: .idle,
            startedAt: startedAt,
            updatedAt: startedAt,
            isCancellable: false
        )
    }

    /// Returns a copy with the requested phase + a refreshed `updatedAt`.
    /// Setting `.completed`, `.cancelled` or `.failed` clears `isCancellable`.
    public func transitioned(to newPhase: Phase, at instant: Date = Date()) -> LocalTimelineImportProgress {
        var copy = self
        copy.phase = newPhase
        copy.updatedAt = instant
        switch newPhase {
        case .idle, .completed, .cancelled, .failed:
            copy.isCancellable = false
        case .preparing, .sniffing, .importing, .finalizing:
            copy.isCancellable = true
        }
        return copy
    }
}

/// Throttled callback delivered to the importer. Producers must not call
/// this per-byte or per-entry — see `LocalTimelineImportProgressThrottle`.
public typealias LocalTimelineImportProgressSink = @Sendable (LocalTimelineImportProgress) -> Void

/// Helper that decides when an updated progress snapshot should fire.
/// Default: every 500 entries OR on phase change OR on completion.
public struct LocalTimelineImportProgressThrottle: Sendable {
    public let entryStride: Int
    public init(entryStride: Int = 500) {
        precondition(entryStride > 0, "entryStride must be > 0")
        self.entryStride = entryStride
    }

    public func shouldEmit(
        previous: LocalTimelineImportProgress?,
        current: LocalTimelineImportProgress
    ) -> Bool {
        guard let previous else { return true }
        if previous.phase != current.phase { return true }
        switch current.phase {
        case .completed, .cancelled, .failed:
            return true
        default:
            break
        }
        let delta = current.entriesProcessed - previous.entriesProcessed
        return delta >= entryStride
    }
}
