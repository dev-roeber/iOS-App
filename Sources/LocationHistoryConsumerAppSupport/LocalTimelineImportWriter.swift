import Foundation
import LocationHistoryConsumer

/// Disk-first writer for the LocalTimelineStore (Phase 2).
///
/// The writer is the only intended way to land entries in the store: callers
/// (e.g. `GoogleTimelineStoreImporter`) push visits/activities/paths one at a
/// time; the writer batches them inside a single SQLite transaction and only
/// holds a small per-day aggregator (`route_count`, `visit_count`, summed
/// `distance_m`, day-id) in RAM. Path coordinates pass through
/// `CoordBlobEncoder` straight to `paths.coord_blob` — no `[Path]`,
/// `[Visit]`, `[Activity]` or full `AppExport` is materialised.
///
/// Lifecycle: `init(store:source:)` → many `addVisit/addActivity/addPath`
/// → `finalize() -> LocalTimelineImportSummary`. After `finalize()` (or a
/// thrown error followed by `cancel()`) the writer must not be reused.
///
/// **Robustness**: malformed entries are *skipped*, not thrown. The writer
/// counts skipped entries in `LocalTimelineImportSummary.skippedEntries`.
/// This matches the existing `GoogleTimelineConverter` behaviour (silently
/// drops entries that fail per-field validation) — Phase 2 surfaces the
/// count instead of swallowing it.
public final class LocalTimelineImportWriter {

    public struct Options {
        public var dateFormatter: DateFormatter
        public var idGenerator: () -> String
        public var clock: () -> Date

        public init(dateFormatter: DateFormatter? = nil,
                    idGenerator: @escaping () -> String = { UUID().uuidString },
                    clock: @escaping () -> Date = { Date() }) {
            if let dateFormatter {
                self.dateFormatter = dateFormatter
            } else {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                self.dateFormatter = f
            }
            self.idGenerator = idGenerator
            self.clock = clock
        }
    }

    public struct VisitInput {
        public var startTime: String?
        public var endTime: String?
        public var latitude: Double?
        public var longitude: Double?
        public var name: String?
        public var semanticType: String?
        public var placeId: String?
        public var probability: Double?
        public init(startTime: String? = nil, endTime: String? = nil,
                    latitude: Double? = nil, longitude: Double? = nil,
                    name: String? = nil, semanticType: String? = nil,
                    placeId: String? = nil, probability: Double? = nil) {
            self.startTime = startTime; self.endTime = endTime
            self.latitude = latitude; self.longitude = longitude
            self.name = name; self.semanticType = semanticType
            self.placeId = placeId; self.probability = probability
        }
    }

    public struct ActivityInput {
        public var startTime: String?
        public var endTime: String?
        public var mode: String?
        public var distanceM: Double?
        public var startLat: Double?
        public var startLon: Double?
        public var endLat: Double?
        public var endLon: Double?
        public var probability: Double?
        public var rawType: String?
        public init(startTime: String? = nil, endTime: String? = nil,
                    mode: String? = nil, distanceM: Double? = nil,
                    startLat: Double? = nil, startLon: Double? = nil,
                    endLat: Double? = nil, endLon: Double? = nil,
                    probability: Double? = nil, rawType: String? = nil) {
            self.startTime = startTime; self.endTime = endTime
            self.mode = mode; self.distanceM = distanceM
            self.startLat = startLat; self.startLon = startLon
            self.endLat = endLat; self.endLon = endLon
            self.probability = probability; self.rawType = rawType
        }
    }

    public struct PathInput {
        public var startTime: String?
        public var endTime: String?
        public var mode: String?
        public var distanceM: Double
        public var flatCoordinates: [Double]
        public init(startTime: String? = nil, endTime: String? = nil,
                    mode: String? = nil, distanceM: Double = 0,
                    flatCoordinates: [Double]) {
            self.startTime = startTime; self.endTime = endTime
            self.mode = mode; self.distanceM = distanceM
            self.flatCoordinates = flatCoordinates
        }
    }

    private struct DayAggregate {
        let id: String
        var routeCount: Int = 0
        var visitCount: Int = 0
        var distanceM: Double = 0
    }

    private let store: LocalTimelineStore
    private let importId: String
    private let options: Options
    private var days: [String: DayAggregate] = [:]
    private var skippedEntries: Int = 0
    private var totalEntries: Int = 0
    private var transactionStarted = false
    private var finalized = false

    /// Begin a new import. Opens a single SQLite transaction and inserts the
    /// `imports` row immediately so dependent inserts have a parent.
    public init(store: LocalTimelineStore,
                source: String,
                options: Options = Options()) throws {
        self.store = store
        self.importId = options.idGenerator()
        self.options = options
        try store.exec_BEGIN_IMMEDIATE()
        transactionStarted = true
        let createdAt = _isoWithoutMs.string(from: options.clock())
        try store.insertImport(.init(id: importId, sourceFilename: source, createdAt: createdAt))
    }

    public var currentImportId: String { importId }

    /// Add a visit. The writer derives the day from `startTime` (UTC). If
    /// `startTime` is missing or unparseable, the visit is dropped.
    public func addVisit(_ input: VisitInput) throws {
        totalEntries += 1
        guard let dayKey = dayKey(forISO: input.startTime) else {
            skippedEntries += 1
            return
        }
        let dayId = try ensureDay(forKey: dayKey).id
        try store.insertVisit(.init(
            id: options.idGenerator(),
            dayId: dayId,
            startTime: input.startTime,
            endTime: input.endTime,
            latitude: input.latitude,
            longitude: input.longitude,
            name: input.name,
            semanticType: input.semanticType,
            placeId: input.placeId,
            probability: input.probability
        ))
        days[dayKey]?.visitCount += 1
    }

    public func addActivity(_ input: ActivityInput, includeStartEndPath: Bool = true) throws {
        totalEntries += 1
        guard let dayKey = dayKey(forISO: input.startTime) else {
            skippedEntries += 1
            return
        }
        let dayId = try ensureDay(forKey: dayKey).id
        try store.insertActivity(.init(
            id: options.idGenerator(),
            dayId: dayId,
            startTime: input.startTime,
            endTime: input.endTime,
            mode: input.mode,
            distanceM: input.distanceM,
            startLat: input.startLat,
            startLon: input.startLon,
            endLat: input.endLat,
            endLon: input.endLon,
            probability: input.probability,
            rawType: input.rawType
        ))
        if let dist = input.distanceM, dist.isFinite {
            days[dayKey]?.distanceM += dist
        }
        if includeStartEndPath,
           let sLat = input.startLat, let sLon = input.startLon,
           let eLat = input.endLat,   let eLon = input.endLon,
           sLat.isFinite, sLon.isFinite, eLat.isFinite, eLon.isFinite {
            let flat = [sLat, sLon, eLat, eLon]
            try addPath(.init(
                startTime: input.startTime, endTime: input.endTime,
                mode: input.mode ?? input.rawType,
                distanceM: input.distanceM ?? 0,
                flatCoordinates: flat
            ), dayKeyOverride: dayKey)
            // addPath increments routeCount itself.
        }
    }

    public func addPath(_ input: PathInput, dayKeyOverride: String? = nil) throws {
        totalEntries += 1
        let dayKey: String
        if let dayKeyOverride {
            dayKey = dayKeyOverride
        } else if let key = self.dayKey(forISO: input.startTime) {
            dayKey = key
        } else {
            skippedEntries += 1
            return
        }
        guard input.flatCoordinates.count >= 4,
              input.flatCoordinates.count.isMultiple(of: 2) else {
            skippedEntries += 1
            return
        }
        let dayId = try ensureDay(forKey: dayKey).id
        let bbox = boundingBox(of: input.flatCoordinates)
        let blob: Data
        do {
            blob = try CoordBlobEncoder.encode(flatCoordinates: input.flatCoordinates)
        } catch {
            skippedEntries += 1
            return
        }
        let pointCount = input.flatCoordinates.count / 2
        try store.insertPath(.init(
            id: options.idGenerator(),
            dayId: dayId,
            startTime: input.startTime,
            endTime: input.endTime,
            mode: input.mode,
            distanceM: input.distanceM,
            pointCount: pointCount,
            minLat: bbox.minLat, minLon: bbox.minLon,
            maxLat: bbox.maxLat, maxLon: bbox.maxLon,
            coordEncoding: CoordBlobEncoding.int32MicrodegreesV1,
            coordBlob: blob
        ))
        days[dayKey]?.routeCount += 1
        if input.distanceM.isFinite, dayKeyOverride == nil {
            days[dayKey]?.distanceM += input.distanceM
        }
    }

    /// Flush day summaries, commit the transaction, return a summary.
    @discardableResult
    public func finalize() throws -> LocalTimelineImportSummary {
        precondition(!finalized, "LocalTimelineImportWriter.finalize() called twice")
        // Apply summaries inside the same transaction.
        for (_, agg) in days {
            try store.updateDaySummary(
                id: agg.id,
                routeCount: agg.routeCount,
                visitCount: agg.visitCount,
                distanceM: agg.distanceM
            )
        }
        try store.exec_COMMIT()
        transactionStarted = false
        finalized = true
        // P1-C — best-effort WAL-Truncate nach erfolgreichem Import.
        // Fehler hier dürfen den bereits committeten Import NICHT
        // versenken; daher absichtlich `bestEffortTruncateWAL`.
        _ = store.bestEffortTruncateWAL()
        let summary = LocalTimelineImportSummary(
            importId: importId,
            dayCount: days.count,
            totalEntries: totalEntries,
            skippedEntries: skippedEntries
        )
        days.removeAll(keepingCapacity: false)
        return summary
    }

    /// Roll back without persisting. Safe to call after a thrown error.
    public func cancel() {
        guard transactionStarted else { return }
        try? store.exec_ROLLBACK()
        transactionStarted = false
        finalized = true
        // P1-C — nach Rollback WAL best-effort kürzen, damit ein
        // halbgefülltes `-wal`-File nicht zurückbleibt.
        _ = store.bestEffortTruncateWAL()
        days.removeAll(keepingCapacity: false)
    }

    // MARK: - Private

    private func ensureDay(forKey dayKey: String) throws -> DayAggregate {
        if let existing = days[dayKey] { return existing }
        let dayId = options.idGenerator()
        try store.insertDay(.init(
            id: dayId, importId: importId, date: dayKey,
            routeCount: 0, visitCount: 0, distanceM: 0
        ))
        let aggregate = DayAggregate(id: dayId)
        days[dayKey] = aggregate
        return aggregate
    }

    private func dayKey(forISO iso: String?) -> String? {
        guard let iso, let date = parseISO(iso) else { return nil }
        return options.dateFormatter.string(from: date)
    }

    private func boundingBox(of flat: [Double])
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)
    {
        var minLat = Double.infinity, minLon = Double.infinity
        var maxLat = -Double.infinity, maxLon = -Double.infinity
        var i = 0
        while i + 1 < flat.count {
            let lat = flat[i], lon = flat[i + 1]
            if lat < minLat { minLat = lat }
            if lat > maxLat { maxLat = lat }
            if lon < minLon { minLon = lon }
            if lon > maxLon { maxLon = lon }
            i += 2
        }
        return (minLat, minLon, maxLat, maxLon)
    }
}

/// Summary returned by `LocalTimelineImportWriter.finalize()`.
public struct LocalTimelineImportSummary: Equatable {
    public let importId: String
    public let dayCount: Int
    public let totalEntries: Int
    public let skippedEntries: Int
    public init(importId: String, dayCount: Int, totalEntries: Int, skippedEntries: Int) {
        self.importId = importId
        self.dayCount = dayCount
        self.totalEntries = totalEntries
        self.skippedEntries = skippedEntries
    }
}

// MARK: - ISO parsing (writer-private, mirrors GoogleTimelineConverter)

private let _isoWithMs: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let _isoWithoutMs: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private func parseISO(_ str: String) -> Date? {
    _isoWithMs.date(from: str) ?? _isoWithoutMs.date(from: str)
}

// MARK: - Transaction primitives reused from the store

extension LocalTimelineStore {
    /// `BEGIN IMMEDIATE` without committing — used by writers that need to
    /// hold the transaction across many calls.
    func exec_BEGIN_IMMEDIATE() throws { try execRaw("BEGIN IMMEDIATE;") }
    func exec_COMMIT() throws         { try execRaw("COMMIT;") }
    func exec_ROLLBACK() throws       { try execRaw("ROLLBACK;") }
}
