import Foundation
import LocationHistoryConsumer

/// Phase-3 read-surface for the LocalTimelineStore.
///
/// `LocalTimelineStoreReader` is a thin, Foundation-only adapter on top of
/// `LocalTimelineStore`. It exists so that DayList / DayDetail / Map
/// preparation code can read the on-disk store **without** importing the
/// SQLite handle, the persistence row structs, or any `AppExport` symbol.
///
/// **Bounded-read invariants** (enforced by the methods below):
///
/// 1. `imports()` reads `imports` only — never paths/visits/activities.
/// 2. `days(forImportId:)` reads `days` only — never `coord_blob`.
/// 3. `dayDetail(dayId:)` reads `days` + `visits` + `activities` + path
///    **metadata** only. Coordinates are not decoded.
/// 4. Path coordinates are reachable only via
///    `coordinateSequence(forPathId:)`, which decodes a single path lazily
///    via `CoordBlobIterator`.
/// 5. No method materialises an `AppExport` or a full `[Double]` for an
///    entire import.
///
/// The reader is **not** `Sendable` and not internally synchronised — it
/// shares the store's single-owning-thread assumption.
public final class LocalTimelineStoreReader {

    public enum ReaderError: Error, Equatable, CustomStringConvertible {
        /// The path id was found, but its blob length is not a multiple of
        /// `CoordBlobEncoding.bytesPerPoint`. Wraps the `CoordBlobError`
        /// thrown by `CoordBlobIterator`.
        case malformedCoordBlob(pathId: String, byteCount: Int)
        /// Path id was not present in the store.
        case unknownPath(pathId: String)

        public var description: String {
            switch self {
            case let .malformedCoordBlob(pathId, byteCount):
                return "malformedCoordBlob(pathId: \(pathId), byteCount: \(byteCount))"
            case let .unknownPath(pathId):
                return "unknownPath(pathId: \(pathId))"
            }
        }
    }

    private let store: LocalTimelineStore

    public init(store: LocalTimelineStore) {
        self.store = store
    }

    // MARK: - Imports

    public func imports() throws -> [LocalTimelineImportRecord] {
        try store.imports().map(Self.toRecord(_:))
    }

    public func importRecord(id: String) throws -> LocalTimelineImportRecord? {
        try store.importRow(id: id).map(Self.toRecord(_:))
    }

    public func latestImport() throws -> LocalTimelineImportRecord? {
        try store.latestImport().map(Self.toRecord(_:))
    }

    // MARK: - Days

    public func days(forImportId importId: String) throws -> [LocalTimelineDayRecord] {
        try store.days(forImportId: importId).map(Self.toRecord(_:))
    }

    public func dayRecord(id: String) throws -> LocalTimelineDayRecord? {
        try store.dayRow(id: id).map(Self.toRecord(_:))
    }

    public func dayRecord(forImportId importId: String, date: String) throws -> LocalTimelineDayRecord? {
        try store.dayRow(forImportId: importId, date: date).map(Self.toRecord(_:))
    }

    public func dayCount(forImportId importId: String) throws -> Int {
        try store.dayCount(forImportId: importId)
    }

    // MARK: - Day detail

    /// Bounded snapshot for a single day. Returns `nil` if `dayId` is
    /// unknown. Reads day-summary + visits + activities + path **metadata**;
    /// path coordinates are **not** decoded.
    public func dayDetail(dayId: String) throws -> LocalTimelineDayDetailSnapshot? {
        guard let day = try store.dayRow(id: dayId) else { return nil }
        let visits = try store.visits(forDayId: dayId).map(Self.toRecord(_:))
        let activities = try store.activities(forDayId: dayId).map(Self.toRecord(_:))
        let paths = try store.pathMetadata(forDayId: dayId)
        return LocalTimelineDayDetailSnapshot(
            day: Self.toRecord(day),
            visits: visits,
            activities: activities,
            paths: paths
        )
    }

    // MARK: - Paths

    public func paths(forDayId dayId: String) throws -> [LocalTimelinePathRecord] {
        try store.pathMetadata(forDayId: dayId)
    }

    /// Phase-8A bounded bbox metadata query for a whole import. Ordered
    /// newest-first by `start_time`. **Never** reads `coord_blob`.
    public func pathMetadata(forImportId importId: String,
                             viewport: LocalTimelineMapViewport,
                             limit: Int) throws -> [LocalTimelinePathRecord] {
        try store.pathMetadata(
            forImportId: importId,
            viewportMinLat: viewport.minLat, viewportMinLon: viewport.minLon,
            viewportMaxLat: viewport.maxLat, viewportMaxLon: viewport.maxLon,
            limit: limit
        )
    }

    /// Phase-8A bounded bbox metadata query for a single day.
    public func pathMetadata(forDayId dayId: String,
                             viewport: LocalTimelineMapViewport,
                             limit: Int) throws -> [LocalTimelinePathRecord] {
        try store.pathMetadata(
            forDayId: dayId,
            viewportMinLat: viewport.minLat, viewportMinLon: viewport.minLon,
            viewportMaxLat: viewport.maxLat, viewportMaxLon: viewport.maxLon,
            limit: limit
        )
    }

    /// Phase-8A: aggregierte Bounding-Box über alle Pfade eines Imports.
    /// Liest nur `min/max_lat/lon`-Spalten — kein `coord_blob`.
    public func pathBoundingBox(forImportId importId: String) throws
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?
    {
        try store.pathBoundingBox(forImportId: importId)
    }

    public func pathBoundingBox(forDayId dayId: String) throws
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?
    {
        try store.pathBoundingBox(forDayId: dayId)
    }

    public func pathRecord(id: String) throws -> LocalTimelinePathRecord? {
        try store.pathMetadata(id: id)
    }

    /// Decode the coordinates of a single path lazily. Returns a
    /// `CoordBlobIterator` (`Sequence`/`IteratorProtocol`) that walks the
    /// blob 8 bytes at a time without ever materialising a `[Double]`.
    /// Throws `ReaderError.unknownPath` if the path id is missing and
    /// `ReaderError.malformedCoordBlob` if the blob length is invalid.
    public func coordinateSequence(forPathId pathId: String) throws -> CoordBlobIterator {
        guard let blob = try store.coordBlob(forPathId: pathId) else {
            throw ReaderError.unknownPath(pathId: pathId)
        }
        do {
            return try CoordBlobIterator(blob: blob)
        } catch CoordBlobError.malformedBlobLength(let n) {
            throw ReaderError.malformedCoordBlob(pathId: pathId, byteCount: n)
        }
    }

    // MARK: - Optional aggregates

    public func dayDateRange(forImportId importId: String) throws -> ClosedRange<String>? {
        guard let bounds = try store.dayDateRange(forImportId: importId) else { return nil }
        if bounds.0 > bounds.1 { return bounds.1...bounds.0 }
        return bounds.0...bounds.1
    }

    public func totalDistance(forImportId importId: String) throws -> Double {
        try store.totalDistance(forImportId: importId)
    }

    public func totalRouteCount(forImportId importId: String) throws -> Int {
        try store.totalRouteCount(forImportId: importId)
    }

    public func totalVisitCount(forImportId importId: String) throws -> Int {
        try store.totalVisitCount(forImportId: importId)
    }

    // MARK: - Row → Record mapping

    private static func toRecord(_ row: ImportRow) -> LocalTimelineImportRecord {
        LocalTimelineImportRecord(
            id: row.id, sourceFilename: row.sourceFilename, createdAt: row.createdAt
        )
    }

    private static func toRecord(_ row: DayRow) -> LocalTimelineDayRecord {
        LocalTimelineDayRecord(
            id: row.id, importId: row.importId, date: row.date,
            routeCount: row.routeCount, visitCount: row.visitCount,
            distanceM: row.distanceM
        )
    }

    private static func toRecord(_ row: VisitRow) -> LocalTimelineVisitRecord {
        LocalTimelineVisitRecord(
            id: row.id, dayId: row.dayId,
            startTime: row.startTime, endTime: row.endTime,
            latitude: row.latitude, longitude: row.longitude,
            name: row.name, semanticType: row.semanticType,
            placeId: row.placeId, probability: row.probability
        )
    }

    private static func toRecord(_ row: ActivityRow) -> LocalTimelineActivityRecord {
        LocalTimelineActivityRecord(
            id: row.id, dayId: row.dayId,
            startTime: row.startTime, endTime: row.endTime,
            mode: row.mode, distanceM: row.distanceM,
            startLat: row.startLat, startLon: row.startLon,
            endLat: row.endLat, endLon: row.endLon,
            probability: row.probability, rawType: row.rawType
        )
    }
}
