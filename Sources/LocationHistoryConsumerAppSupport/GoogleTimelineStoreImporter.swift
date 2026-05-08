import Foundation
import LocationHistoryConsumer

/// Disk-first importer for Google Timeline JSON / ZIP into the
/// `LocalTimelineStore` (Phase 2).
///
/// Sits on top of the existing `GoogleTimelineStreamReader` (object-by-object,
/// per-element peak ~few KB) and forwards each entry to a
/// `LocalTimelineImportWriter` that batches inserts inside a single SQLite
/// transaction. **No `AppExport` is built.** No `[Day]`, `[Visit]`,
/// `[Activity]`, or `[Path]` accumulators exist on the import path — the
/// only retained per-day state is a small aggregator (`route_count`,
/// `visit_count`, summed `distance_m`, `dayId`).
///
/// Phase-10A P1-A/P1-B: an optional `Hooks` value lets callers attach a
/// throttled progress sink and a cooperative cancellation token. When
/// cancellation is observed the writer rolls back its open transaction
/// (no partial import is left as a valid one) and the call throws
/// `LocalTimelineImportCancellationError.cancelled`. With no hooks the
/// behaviour is identical to the legacy entry points.
public enum GoogleTimelineStoreImporter {

    public enum ImportError: Error {
        case notGoogleTimeline
        case streamFailed(underlying: Error)
        case writeFailed(underlying: Error)
    }

    /// Optional cancel/progress wiring. Both fields default to nil — passing
    /// `Hooks()` is equivalent to the legacy non-cancellable, non-progressing
    /// import path.
    public struct Hooks: Sendable {
        public var progress: LocalTimelineImportProgressSink?
        public var throttle: LocalTimelineImportProgressThrottle
        public var cancellation: LocalTimelineImportCancellation?
        public var clock: @Sendable () -> Date

        public init(
            progress: LocalTimelineImportProgressSink? = nil,
            throttle: LocalTimelineImportProgressThrottle = .init(),
            cancellation: LocalTimelineImportCancellation? = nil,
            clock: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.progress = progress
            self.throttle = throttle
            self.cancellation = cancellation
            self.clock = clock
        }
    }

    /// Stream a Google Timeline JSON file directly into the store.
    /// Returns the resulting import-id + day count + entry totals.
    @discardableResult
    public static func importFromFile(
        url: URL,
        sourceFilename: String? = nil,
        store: LocalTimelineStore,
        writerOptions: LocalTimelineImportWriter.Options = .init(),
        hooks: Hooks = Hooks()
    ) throws -> LocalTimelineImportSummary {
        let totalBytes: Int64? = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64)
            ?? (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        var emitter = ProgressEmitter(hooks: hooks, totalBytes: totalBytes)
        emitter.transition(to: .preparing)

        do {
            try hooks.cancellation?.checkCancellation()
        } catch {
            emitter.transition(to: .cancelled)
            throw error
        }

        let writer: LocalTimelineImportWriter
        do {
            writer = try LocalTimelineImportWriter(
                store: store,
                source: sourceFilename ?? url.lastPathComponent,
                options: writerOptions
            )
        } catch {
            emitter.transition(to: .failed)
            throw error
        }

        emitter.transition(to: .importing)
        do {
            try GoogleTimelineStreamReader.forEachObjectElement(contentsOf: url) { raw in
                try hooks.cancellation?.checkCancellation()
                try ingest(raw, writer: writer, emitter: &emitter, hooks: hooks)
            }
            try hooks.cancellation?.checkCancellation()
            emitter.transition(to: .finalizing)
            let summary = try writer.finalize()
            emitter.applySummary(summary)
            emitter.transition(to: .completed)
            return summary
        } catch {
            writer.cancel()
            try rethrowImporterError(error, emitter: &emitter)
        }
    }

    /// Stream a Google Timeline JSON `Data` (already in memory, e.g. from a
    /// ZIP entry) directly into the store.
    @discardableResult
    public static func importFromData(
        _ data: Data,
        sourceFilename: String,
        store: LocalTimelineStore,
        writerOptions: LocalTimelineImportWriter.Options = .init(),
        hooks: Hooks = Hooks()
    ) throws -> LocalTimelineImportSummary {
        var emitter = ProgressEmitter(hooks: hooks, totalBytes: Int64(data.count))
        emitter.transition(to: .preparing)

        do {
            try hooks.cancellation?.checkCancellation()
        } catch {
            emitter.transition(to: .cancelled)
            throw error
        }

        let writer: LocalTimelineImportWriter
        do {
            writer = try LocalTimelineImportWriter(
                store: store, source: sourceFilename, options: writerOptions
            )
        } catch {
            emitter.transition(to: .failed)
            throw error
        }

        emitter.transition(to: .importing)
        do {
            try GoogleTimelineStreamReader.forEachObjectElement(in: data) { raw in
                try hooks.cancellation?.checkCancellation()
                try ingest(raw, writer: writer, emitter: &emitter, hooks: hooks)
            }
            try hooks.cancellation?.checkCancellation()
            emitter.transition(to: .finalizing)
            let summary = try writer.finalize()
            emitter.applySummary(summary)
            emitter.transition(to: .completed)
            return summary
        } catch {
            writer.cancel()
            try rethrowImporterError(error, emitter: &emitter)
        }
    }

    // MARK: - Per-entry dispatch

    private static func ingest(
        _ raw: Any,
        writer: LocalTimelineImportWriter,
        emitter: inout ProgressEmitter,
        hooks: Hooks
    ) throws {
        guard let entry = raw as? [String: Any] else {
            emitter.recordSkippedEntry()
            return
        }
        let startTime = entry["startTime"] as? String
        let endTime = entry["endTime"] as? String

        if let visitData = entry["visit"] as? [String: Any] {
            let candidate = visitData["topCandidate"] as? [String: Any]
            let coord = parseGeo(candidate?["placeLocation"] as? String)
            try writer.addVisit(.init(
                startTime: startTime,
                endTime: endTime,
                latitude: coord?.lat,
                longitude: coord?.lon,
                name: candidate?["semanticType"] as? String,
                semanticType: candidate?["semanticType"] as? String,
                placeId: candidate?["placeID"] as? String,
                probability: parseDouble(visitData["probability"])
                    ?? parseDouble(candidate?["probability"])
            ))
            emitter.recordVisit()
        } else if let activityData = entry["activity"] as? [String: Any] {
            let candidate = activityData["topCandidate"] as? [String: Any]
            let start = parseGeo(activityData["start"] as? String)
            let end = parseGeo(activityData["end"] as? String)
            let mode = candidate?["type"] as? String
            try writer.addActivity(.init(
                startTime: startTime,
                endTime: endTime,
                mode: mode,
                distanceM: parseDouble(activityData["distanceMeters"]),
                startLat: start?.lat, startLon: start?.lon,
                endLat: end?.lat, endLon: end?.lon,
                probability: parseDouble(activityData["probability"])
                    ?? parseDouble(candidate?["probability"]),
                rawType: mode
            ))
            emitter.recordActivity()
        } else if let pathData = entry["timelinePath"] as? [[String: Any]] {
            var flat: [Double] = []
            flat.reserveCapacity(pathData.count * 2)
            for pt in pathData {
                guard let geo = pt["point"] as? String,
                      let coord = parseGeo(geo) else { continue }
                flat.append(coord.lat)
                flat.append(coord.lon)
            }
            if flat.count >= 4 {
                try writer.addPath(.init(
                    startTime: startTime,
                    endTime: endTime,
                    mode: nil,
                    distanceM: 0,
                    flatCoordinates: flat
                ))
                emitter.recordPath()
            } else {
                emitter.recordSkippedEntry()
            }
        } else {
            // Entries without a recognised payload are silently skipped — same
            // behaviour as `GoogleTimelineConverter.ExportBuilder.ingest`.
            emitter.recordSkippedEntry()
        }
    }

    private static func rethrowImporterError(
        _ error: Error,
        emitter: inout ProgressEmitter
    ) throws -> Never {
        if error is LocalTimelineImportCancellationError {
            emitter.transition(to: .cancelled)
            throw error
        }
        emitter.transition(to: .failed)
        if error is LocalTimelineStoreError {
            throw ImportError.writeFailed(underlying: error)
        }
        if let stream = error as? GoogleTimelineStreamReader.StreamError {
            throw ImportError.streamFailed(underlying: stream)
        }
        throw error
    }

    private static func parseGeo(_ geo: String?) -> (lat: Double, lon: Double)? {
        guard let geo, geo.hasPrefix("geo:") else { return nil }
        let parts = geo.dropFirst(4).split(separator: ",")
        guard parts.count >= 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (lat, lon)
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }
}

// MARK: - Progress emitter (file-private helper)

private struct ProgressEmitter {
    let hooks: GoogleTimelineStoreImporter.Hooks
    private(set) var current: LocalTimelineImportProgress
    private var lastEmitted: LocalTimelineImportProgress?

    init(hooks: GoogleTimelineStoreImporter.Hooks, totalBytes: Int64?) {
        self.hooks = hooks
        let now = hooks.clock()
        self.current = LocalTimelineImportProgress(
            phase: .idle,
            bytesRead: nil,
            totalBytes: totalBytes,
            startedAt: now,
            updatedAt: now,
            isCancellable: false
        )
        if hooks.progress != nil {
            emit(force: true)
        }
    }

    mutating func transition(to phase: LocalTimelineImportProgress.Phase) {
        guard hooks.progress != nil else { return }
        current = current.transitioned(to: phase, at: hooks.clock())
        emit(force: true)
    }

    mutating func recordVisit() {
        guard hooks.progress != nil else { return }
        current.entriesProcessed += 1
        current.visitsWritten += 1
        current.updatedAt = hooks.clock()
        emit(force: false)
    }

    mutating func recordActivity() {
        guard hooks.progress != nil else { return }
        current.entriesProcessed += 1
        current.activitiesWritten += 1
        current.updatedAt = hooks.clock()
        emit(force: false)
    }

    mutating func recordPath() {
        guard hooks.progress != nil else { return }
        current.entriesProcessed += 1
        current.pathsWritten += 1
        current.updatedAt = hooks.clock()
        emit(force: false)
    }

    mutating func recordSkippedEntry() {
        guard hooks.progress != nil else { return }
        current.entriesProcessed += 1
        current.skippedEntries += 1
        current.updatedAt = hooks.clock()
        emit(force: false)
    }

    mutating func applySummary(_ summary: LocalTimelineImportSummary) {
        guard hooks.progress != nil else { return }
        // Importer-side skips (entries with no recognised payload or
        // malformed paths) and writer-side skips (entries dropped because
        // their timestamp is unparseable) are disjoint — the writer never
        // sees the entries the importer rejected. Sum so the final
        // `skippedEntries` equals the union seen by the user.
        current.skippedEntries += summary.skippedEntries
        current.updatedAt = hooks.clock()
    }

    private mutating func emit(force: Bool) {
        guard let sink = hooks.progress else { return }
        if force || hooks.throttle.shouldEmit(previous: lastEmitted, current: current) {
            sink(current)
            lastEmitted = current
        }
    }
}
