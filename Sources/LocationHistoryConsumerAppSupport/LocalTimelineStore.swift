import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

/// Phase-1 isolated spike of a SQLite-backed LocalTimelineStore.
///
/// Not wired into any app flow. Production reads still go through the
/// in-memory `AppExport` pipeline. This type exists so the Linux CI can
/// exercise the SQL plan documented in
/// `docs/LOCAL_TIMELINE_STORE_RESEARCH.md` against a real SQLite engine
/// before any UI surface gets migrated.
///
/// Threading: not Sendable, not internally synchronised. The spike assumes
/// a single owning thread (test or future writer/reader actor).
public final class LocalTimelineStore {

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self
    )

    private var db: OpaquePointer?
    public let path: String

    /// Open or create a database at `url`. The file is created if missing
    /// and the schema is applied idempotently. Foreign keys are enforced.
    public init(url: URL) throws {
        self.path = url.path
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let openCode = sqlite3_open_v2(path, &handle, flags, nil)
        guard openCode == SQLITE_OK, let opened = handle else {
            let msg = handle.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "unknown"
            if let opened = handle { sqlite3_close_v2(opened) }
            throw LocalTimelineStoreError.openFailed(path: path, code: openCode, message: msg)
        }
        self.db = opened
        try exec("PRAGMA foreign_keys = ON;")
        try exec("PRAGMA journal_mode = WAL;")
        // Performance pragmas — all WAL-safe and recommended by sqlite.org for
        // single-writer app stores. `busy_timeout` makes concurrent open
        // handles wait instead of immediately failing with SQLITE_BUSY;
        // `synchronous = NORMAL` is the SQLite-documented safe pairing for
        // WAL on application data (the page cache + WAL replay covers crash
        // recovery for app-loss; only catastrophic power loss could lose the
        // last transaction, which is acceptable here because the store is
        // user-rebuildable from the import file); `temp_store = MEMORY`
        // keeps SQLite scratch out of the file system.
        try exec("PRAGMA busy_timeout = 3000;")
        try exec("PRAGMA synchronous = NORMAL;")
        try exec("PRAGMA temp_store = MEMORY;")
        // Bound WAL growth and let SQLite checkpoint automatically. The
        // explicit `checkpointWAL` API still runs at import finalize and
        // on store delete; these pragmas just keep idle WAL from growing
        // unbounded between explicit checkpoints. `journal_size_limit`
        // caps the WAL file after each checkpoint truncation; setting it
        // to ~16 MiB matches the typical app-store burst size we observe
        // during a large Google Timeline import. `wal_autocheckpoint`
        // (default 1000 pages = ~4 MiB) is made explicit for clarity.
        try exec("PRAGMA journal_size_limit = 16777216;")
        try exec("PRAGMA wal_autocheckpoint = 1000;")
        try applySchema()
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    /// Drop the underlying handle; safe to call multiple times.
    public func close() {
        if let db {
            sqlite3_close_v2(db)
            self.db = nil
        }
    }

    // MARK: - Schema

    private func applySchema() throws {
        for stmt in LocalTimelineStoreSchema.allBootstrapStatements {
            try exec(stmt)
        }
        try exec("PRAGMA user_version = \(LocalTimelineStoreSchema.userVersion);")
    }

    public func userVersion() throws -> Int32 {
        let stmt = try prepare("PRAGMA user_version;")
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else {
            throw stepError(rc: rc)
        }
        return sqlite3_column_int(stmt, 0)
    }

    /// Phase-8A — list non-internal index names attached to a given table.
    /// Used by schema-introspection tests to verify additive-index migrations.
    public func indexNames(forTable table: String) throws -> [String] {
        let sql = "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=? AND name NOT LIKE 'sqlite_%';"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: table, name: "tbl_name")
        var out: [String] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            if let name = stringColumn(stmt, 0) { out.append(name) }
        }
        return out
    }

    // MARK: - Write API

    public func insertImport(_ row: ImportRow) throws {
        let sql = "INSERT INTO imports(id, source_filename, created_at) VALUES(?, ?, ?);"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindText(stmt, index: 2, value: row.sourceFilename, name: "source_filename")
        try bindText(stmt, index: 3, value: row.createdAt, name: "created_at")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    public func insertDay(_ row: DayRow) throws {
        let sql = """
        INSERT INTO days(id, import_id, date, route_count, visit_count, distance_m)
        VALUES(?, ?, ?, ?, ?, ?);
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindText(stmt, index: 2, value: row.importId, name: "import_id")
        try bindText(stmt, index: 3, value: row.date, name: "date")
        try bindInt(stmt, index: 4, value: Int32(row.routeCount), name: "route_count")
        try bindInt(stmt, index: 5, value: Int32(row.visitCount), name: "visit_count")
        try bindDouble(stmt, index: 6, value: row.distanceM, name: "distance_m")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_CONSTRAINT { throw LocalTimelineStoreError.foreignKeyViolation }
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    public func insertPath(_ row: PathRow) throws {
        let sql = """
        INSERT INTO paths(id, day_id, start_time, end_time, mode, distance_m,
                          point_count, min_lat, min_lon, max_lat, max_lon,
                          coord_encoding, coord_blob)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindText(stmt, index: 2, value: row.dayId, name: "day_id")
        try bindOptionalText(stmt, index: 3, value: row.startTime, name: "start_time")
        try bindOptionalText(stmt, index: 4, value: row.endTime, name: "end_time")
        try bindOptionalText(stmt, index: 5, value: row.mode, name: "mode")
        try bindDouble(stmt, index: 6, value: row.distanceM, name: "distance_m")
        try bindInt(stmt, index: 7, value: Int32(row.pointCount), name: "point_count")
        try bindOptionalDouble(stmt, index: 8, value: row.minLat, name: "min_lat")
        try bindOptionalDouble(stmt, index: 9, value: row.minLon, name: "min_lon")
        try bindOptionalDouble(stmt, index: 10, value: row.maxLat, name: "max_lat")
        try bindOptionalDouble(stmt, index: 11, value: row.maxLon, name: "max_lon")
        try bindText(stmt, index: 12, value: row.coordEncoding, name: "coord_encoding")
        try bindBlob(stmt, index: 13, value: row.coordBlob, name: "coord_blob")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_CONSTRAINT { throw LocalTimelineStoreError.foreignKeyViolation }
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    /// Run a closure inside `BEGIN IMMEDIATE … COMMIT`. On throw, rolls back.
    public func withTransaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE;")
        do {
            let result = try body()
            try exec("COMMIT;")
            return result
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    public func deleteImport(id: String) throws {
        let sql = "DELETE FROM imports WHERE id = ?;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: id, name: "id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    /// Phase-2 lifecycle hook. Removes every row from
    /// `imports`/`days`/`paths`/`visits`/`activities` in a single
    /// transaction. Idempotent — succeeds on an empty store.
    ///
    /// Scope (Phase-2): **DB rows only**. App-level caches (`Caches/...`,
    /// `tmp/LH2GPX-Import-*/`) are not touched here because no production
    /// flow currently writes to them. The full "user pressed Delete in
    /// Settings" surface — DB + Caches + tmp + bookmark/preferences —
    /// must be wired up in the UI hook iteration *before* the store
    /// becomes user-visible.
    public func deleteAll() throws {
        try withTransaction {
            // Order matters only for clarity — `ON DELETE CASCADE` would
            // make the dependent deletes redundant if we only nuked
            // `imports`. We delete from leaves first so the operation is
            // safe even if a future migration drops the FK chain.
            try exec("DELETE FROM derived_cache;")
            try exec("DELETE FROM activities;")
            try exec("DELETE FROM visits;")
            try exec("DELETE FROM paths;")
            try exec("DELETE FROM days;")
            try exec("DELETE FROM imports;")
        }
    }

    // MARK: - Phase-8B derived_cache CRUD

    /// Schreibt einen Cache-Eintrag (Insert oder Replace per Primärschlüssel `id`).
    /// `cache_kind`+`cache_key` sind anwendungsspezifisch (z. B. Heatmap-LOD).
    public func putDerivedCache(_ row: DerivedCacheRow) throws {
        let sql = """
        INSERT OR REPLACE INTO derived_cache(id, import_id, cache_kind, cache_key,
                                             created_at, version,
                                             payload_encoding, payload_blob)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?);
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindOptionalText(stmt, index: 2, value: row.importId, name: "import_id")
        try bindText(stmt, index: 3, value: row.cacheKind, name: "cache_kind")
        try bindText(stmt, index: 4, value: row.cacheKey, name: "cache_key")
        try bindText(stmt, index: 5, value: row.createdAt, name: "created_at")
        try bindInt(stmt, index: 6, value: Int32(row.version), name: "version")
        try bindText(stmt, index: 7, value: row.payloadEncoding, name: "payload_encoding")
        try bindBlob(stmt, index: 8, value: row.payloadBlob, name: "payload_blob")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_CONSTRAINT { throw LocalTimelineStoreError.foreignKeyViolation }
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    /// Liest einen Cache-Eintrag per `(import_id, cache_kind, cache_key)`. Gibt
    /// den jüngsten (höchste `version`, Tiebreak: created_at DESC) zurück, falls
    /// mehrere Versionen vorhanden sind.
    public func derivedCache(importId: String?,
                             cacheKind: String,
                             cacheKey: String) throws -> DerivedCacheRow? {
        let importPredicate = (importId == nil) ? "import_id IS NULL" : "import_id = ?"
        let sql = """
        SELECT id, import_id, cache_kind, cache_key, created_at, version,
               payload_encoding, payload_blob
        FROM derived_cache
        WHERE \(importPredicate) AND cache_kind = ? AND cache_key = ?
        ORDER BY version DESC, created_at DESC
        LIMIT 1;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        if let importId {
            try bindText(stmt, index: idx, value: importId, name: "import_id")
            idx += 1
        }
        try bindText(stmt, index: idx, value: cacheKind, name: "cache_kind")
        idx += 1
        try bindText(stmt, index: idx, value: cacheKey, name: "cache_key")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return DerivedCacheRow(
            id: stringColumn(stmt, 0) ?? "",
            importId: stringColumn(stmt, 1),
            cacheKind: stringColumn(stmt, 2) ?? "",
            cacheKey: stringColumn(stmt, 3) ?? "",
            createdAt: stringColumn(stmt, 4) ?? "",
            version: Int(sqlite3_column_int64(stmt, 5)),
            payloadEncoding: stringColumn(stmt, 6) ?? "",
            payloadBlob: blobColumn(stmt, 7) ?? Data()
        )
    }

    /// Löscht alle Cache-Einträge eines Imports und (optional) Cache-Kind.
    /// `importId == nil` löscht **nur globale** Einträge. `cacheKind == nil`
    /// löscht alle Kinds des angegebenen Scopes.
    public func deleteDerivedCache(importId: String?, cacheKind: String?) throws {
        let importPredicate = (importId == nil) ? "import_id IS NULL" : "import_id = ?"
        let kindPredicate = cacheKind.map { _ in "AND cache_kind = ?" } ?? ""
        let sql = "DELETE FROM derived_cache WHERE \(importPredicate) \(kindPredicate);"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        if let importId {
            try bindText(stmt, index: idx, value: importId, name: "import_id")
            idx += 1
        }
        if let cacheKind {
            try bindText(stmt, index: idx, value: cacheKind, name: "cache_kind")
        }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    /// Anzahl Cache-Einträge gesamt (über alle Imports/Kinds).
    public func countDerivedCache() throws -> Int { try countRows(in: "derived_cache") }

    /// Phase-10C — löscht alle Cache-Einträge, deren `created_at` lexikographisch
    /// kleiner als `cutoff` ist. `created_at` wird als ISO-8601-String gespeichert,
    /// sodass lexikographische und zeitliche Ordnung übereinstimmen.
    /// `cacheKind == nil` purge-t alle Kinds.
    public func deleteDerivedCache(olderThan cutoff: String, cacheKind: String? = nil) throws {
        let kindPredicate = cacheKind.map { _ in "AND cache_kind = ?" } ?? ""
        let sql = "DELETE FROM derived_cache WHERE created_at < ? \(kindPredicate);"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: cutoff, name: "created_at")
        if let cacheKind {
            try bindText(stmt, index: 2, value: cacheKind, name: "cache_kind")
        }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    /// Phase-10C — Entry-Count-basierter Prune. Hält die Cache-Tabelle (optional
    /// pro `cacheKind`) auf höchstens `maxEntries` Einträge. Älteste werden zuerst
    /// gelöscht (`ORDER BY created_at ASC, version ASC`). Nutzt den Index
    /// `idx_derived_cache_kind_created`. Liefert die Anzahl gelöschter Einträge.
    @discardableResult
    public func pruneDerivedCache(maxEntries: Int, cacheKind: String? = nil) throws -> Int {
        precondition(maxEntries >= 0, "maxEntries must be >= 0")
        let countSQL: String
        let deleteSQL: String
        if let cacheKind {
            countSQL = "SELECT COUNT(*) FROM derived_cache WHERE cache_kind = ?;"
            deleteSQL = """
            DELETE FROM derived_cache WHERE id IN (
              SELECT id FROM derived_cache WHERE cache_kind = ?
              ORDER BY created_at ASC, version ASC LIMIT ?
            );
            """
            let cs = try prepare(countSQL)
            defer { sqlite3_finalize(cs) }
            try bindText(cs, index: 1, value: cacheKind, name: "cache_kind")
            guard sqlite3_step(cs) == SQLITE_ROW else { return 0 }
            let total = Int(sqlite3_column_int64(cs, 0))
            let toDelete = max(0, total - maxEntries)
            if toDelete == 0 { return 0 }
            let ds = try prepare(deleteSQL)
            defer { sqlite3_finalize(ds) }
            try bindText(ds, index: 1, value: cacheKind, name: "cache_kind")
            try bindInt(ds, index: 2, value: Int32(toDelete), name: "limit")
            let rc = sqlite3_step(ds)
            guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
            return toDelete
        } else {
            countSQL = "SELECT COUNT(*) FROM derived_cache;"
            deleteSQL = """
            DELETE FROM derived_cache WHERE id IN (
              SELECT id FROM derived_cache
              ORDER BY created_at ASC, version ASC LIMIT ?
            );
            """
            let cs = try prepare(countSQL)
            defer { sqlite3_finalize(cs) }
            guard sqlite3_step(cs) == SQLITE_ROW else { return 0 }
            let total = Int(sqlite3_column_int64(cs, 0))
            let toDelete = max(0, total - maxEntries)
            if toDelete == 0 { return 0 }
            let ds = try prepare(deleteSQL)
            defer { sqlite3_finalize(ds) }
            try bindInt(ds, index: 1, value: Int32(toDelete), name: "limit")
            let rc = sqlite3_step(ds)
            guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
            return toDelete
        }
    }

    public func updateDaySummary(id: String, routeCount: Int, visitCount: Int, distanceM: Double) throws {
        let sql = """
        UPDATE days SET route_count = ?, visit_count = ?, distance_m = ? WHERE id = ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindInt(stmt, index: 1, value: Int32(routeCount), name: "route_count")
        try bindInt(stmt, index: 2, value: Int32(visitCount), name: "visit_count")
        try bindDouble(stmt, index: 3, value: distanceM, name: "distance_m")
        try bindText(stmt, index: 4, value: id, name: "id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    public func insertVisit(_ row: VisitRow) throws {
        let sql = """
        INSERT INTO visits(id, day_id, start_time, end_time, latitude, longitude,
                           name, semantic_type, place_id, probability)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindText(stmt, index: 2, value: row.dayId, name: "day_id")
        try bindOptionalText(stmt, index: 3, value: row.startTime, name: "start_time")
        try bindOptionalText(stmt, index: 4, value: row.endTime, name: "end_time")
        try bindOptionalDouble(stmt, index: 5, value: row.latitude, name: "latitude")
        try bindOptionalDouble(stmt, index: 6, value: row.longitude, name: "longitude")
        try bindOptionalText(stmt, index: 7, value: row.name, name: "name")
        try bindOptionalText(stmt, index: 8, value: row.semanticType, name: "semantic_type")
        try bindOptionalText(stmt, index: 9, value: row.placeId, name: "place_id")
        try bindOptionalDouble(stmt, index: 10, value: row.probability, name: "probability")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_CONSTRAINT { throw LocalTimelineStoreError.foreignKeyViolation }
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    public func insertActivity(_ row: ActivityRow) throws {
        let sql = """
        INSERT INTO activities(id, day_id, start_time, end_time, mode, distance_m,
                               start_lat, start_lon, end_lat, end_lon, probability, raw_type)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: row.id, name: "id")
        try bindText(stmt, index: 2, value: row.dayId, name: "day_id")
        try bindOptionalText(stmt, index: 3, value: row.startTime, name: "start_time")
        try bindOptionalText(stmt, index: 4, value: row.endTime, name: "end_time")
        try bindOptionalText(stmt, index: 5, value: row.mode, name: "mode")
        try bindOptionalDouble(stmt, index: 6, value: row.distanceM, name: "distance_m")
        try bindOptionalDouble(stmt, index: 7, value: row.startLat, name: "start_lat")
        try bindOptionalDouble(stmt, index: 8, value: row.startLon, name: "start_lon")
        try bindOptionalDouble(stmt, index: 9, value: row.endLat, name: "end_lat")
        try bindOptionalDouble(stmt, index: 10, value: row.endLon, name: "end_lon")
        try bindOptionalDouble(stmt, index: 11, value: row.probability, name: "probability")
        try bindOptionalText(stmt, index: 12, value: row.rawType, name: "raw_type")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_CONSTRAINT { throw LocalTimelineStoreError.foreignKeyViolation }
        guard rc == SQLITE_DONE else { throw stepError(rc: rc) }
    }

    // MARK: - Read API

    public func countImports() throws -> Int { try countRows(in: "imports") }
    public func countDays() throws -> Int { try countRows(in: "days") }
    public func countPaths() throws -> Int { try countRows(in: "paths") }
    public func countVisits() throws -> Int { try countRows(in: "visits") }
    public func countActivities() throws -> Int { try countRows(in: "activities") }

    // MARK: - Phase-3 bounded read helpers

    /// All imports ordered by `created_at` descending, then `id` for stability.
    /// Reads only `imports` columns — never touches `paths`/`visits`/`activities`.
    public func imports() throws -> [ImportRow] {
        let sql = """
        SELECT id, source_filename, created_at FROM imports
        ORDER BY created_at DESC, id DESC;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var out: [ImportRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(ImportRow(
                id: stringColumn(stmt, 0) ?? "",
                sourceFilename: stringColumn(stmt, 1) ?? "",
                createdAt: stringColumn(stmt, 2) ?? ""
            ))
        }
        return out
    }

    public func importRow(id: String) throws -> ImportRow? {
        let sql = "SELECT id, source_filename, created_at FROM imports WHERE id = ? LIMIT 1;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: id, name: "id")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return ImportRow(
            id: stringColumn(stmt, 0) ?? "",
            sourceFilename: stringColumn(stmt, 1) ?? "",
            createdAt: stringColumn(stmt, 2) ?? ""
        )
    }

    public func latestImport() throws -> ImportRow? {
        let sql = """
        SELECT id, source_filename, created_at FROM imports
        ORDER BY created_at DESC, id DESC LIMIT 1;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return ImportRow(
            id: stringColumn(stmt, 0) ?? "",
            sourceFilename: stringColumn(stmt, 1) ?? "",
            createdAt: stringColumn(stmt, 2) ?? ""
        )
    }

    public func dayRow(id: String) throws -> DayRow? {
        let sql = """
        SELECT id, import_id, date, route_count, visit_count, distance_m
        FROM days WHERE id = ? LIMIT 1;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: id, name: "id")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return DayRow(
            id: stringColumn(stmt, 0) ?? "",
            importId: stringColumn(stmt, 1) ?? "",
            date: stringColumn(stmt, 2) ?? "",
            routeCount: Int(sqlite3_column_int(stmt, 3)),
            visitCount: Int(sqlite3_column_int(stmt, 4)),
            distanceM: sqlite3_column_double(stmt, 5)
        )
    }

    public func dayRow(forImportId importId: String, date: String) throws -> DayRow? {
        let sql = """
        SELECT id, import_id, date, route_count, visit_count, distance_m
        FROM days WHERE import_id = ? AND date = ? LIMIT 1;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        try bindText(stmt, index: 2, value: date, name: "date")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return DayRow(
            id: stringColumn(stmt, 0) ?? "",
            importId: stringColumn(stmt, 1) ?? "",
            date: stringColumn(stmt, 2) ?? "",
            routeCount: Int(sqlite3_column_int(stmt, 3)),
            visitCount: Int(sqlite3_column_int(stmt, 4)),
            distanceM: sqlite3_column_double(stmt, 5)
        )
    }

    public func dayCount(forImportId importId: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM days WHERE import_id = ?;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Path metadata for a single day, **without** the `coord_blob`. Used by
    /// the read-surface so DayDetail can list paths and decide which one to
    /// decode lazily.
    public func pathMetadata(forDayId dayId: String) throws -> [LocalTimelinePathRecord] {
        let sql = """
        SELECT id, day_id, start_time, end_time, mode, distance_m, point_count,
               min_lat, min_lon, max_lat, max_lon, coord_encoding
        FROM paths WHERE day_id = ? ORDER BY start_time;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")
        var out: [LocalTimelinePathRecord] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(LocalTimelinePathRecord(
                id: stringColumn(stmt, 0) ?? "",
                dayId: stringColumn(stmt, 1) ?? "",
                startTime: stringColumn(stmt, 2),
                endTime: stringColumn(stmt, 3),
                mode: stringColumn(stmt, 4),
                distanceM: sqlite3_column_double(stmt, 5),
                pointCount: Int(sqlite3_column_int(stmt, 6)),
                minLat: optionalDoubleColumn(stmt, 7),
                minLon: optionalDoubleColumn(stmt, 8),
                maxLat: optionalDoubleColumn(stmt, 9),
                maxLon: optionalDoubleColumn(stmt, 10),
                coordEncoding: stringColumn(stmt, 11) ?? ""
            ))
        }
        return out
    }

    public func pathMetadata(id: String) throws -> LocalTimelinePathRecord? {
        let sql = """
        SELECT id, day_id, start_time, end_time, mode, distance_m, point_count,
               min_lat, min_lon, max_lat, max_lon, coord_encoding
        FROM paths WHERE id = ? LIMIT 1;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: id, name: "id")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return LocalTimelinePathRecord(
            id: stringColumn(stmt, 0) ?? "",
            dayId: stringColumn(stmt, 1) ?? "",
            startTime: stringColumn(stmt, 2),
            endTime: stringColumn(stmt, 3),
            mode: stringColumn(stmt, 4),
            distanceM: sqlite3_column_double(stmt, 5),
            pointCount: Int(sqlite3_column_int(stmt, 6)),
            minLat: optionalDoubleColumn(stmt, 7),
            minLon: optionalDoubleColumn(stmt, 8),
            maxLat: optionalDoubleColumn(stmt, 9),
            maxLon: optionalDoubleColumn(stmt, 10),
            coordEncoding: stringColumn(stmt, 11) ?? ""
        )
    }

    /// Read the raw `coord_blob` for a single path. Returns `nil` if the
    /// path id is unknown. The caller is responsible for handing the blob
    /// to `CoordBlobIterator` for lazy decoding.
    public func coordBlob(forPathId pathId: String) throws -> Data? {
        let sql = "SELECT coord_blob FROM paths WHERE id = ? LIMIT 1;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: pathId, name: "id")
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return blobColumn(stmt, 0) ?? Data()
    }

    /// Phase-8A bounded bbox query: path metadata for an entire import,
    /// filtered to overlap an axis-aligned WGS84 bounding box on
    /// `min/max_lat/lon`. Returns rows ordered newest-first by
    /// `start_time DESC` (NULLs last) with a hard `limit`. **Never** reads
    /// `coord_blob`. Paths with `NULL` bounds are included (they cannot
    /// be filtered safely).
    public func pathMetadata(
        forImportId importId: String,
        viewportMinLat: Double, viewportMinLon: Double,
        viewportMaxLat: Double, viewportMaxLon: Double,
        limit: Int
    ) throws -> [LocalTimelinePathRecord] {
        let sql = """
        SELECT p.id, p.day_id, p.start_time, p.end_time, p.mode, p.distance_m,
               p.point_count, p.min_lat, p.min_lon, p.max_lat, p.max_lon,
               p.coord_encoding
        FROM paths AS p
        JOIN days  AS d ON d.id = p.day_id
        WHERE d.import_id = ?
          AND (p.min_lat IS NULL OR p.max_lat IS NULL
               OR p.min_lon IS NULL OR p.max_lon IS NULL
               OR (p.max_lat >= ? AND p.min_lat <= ?
                   AND p.max_lon >= ? AND p.min_lon <= ?))
        ORDER BY p.start_time IS NULL, p.start_time DESC
        LIMIT ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        try bindDouble(stmt, index: 2, value: viewportMinLat, name: "vp_min_lat")
        try bindDouble(stmt, index: 3, value: viewportMaxLat, name: "vp_max_lat")
        try bindDouble(stmt, index: 4, value: viewportMinLon, name: "vp_min_lon")
        try bindDouble(stmt, index: 5, value: viewportMaxLon, name: "vp_max_lon")
        try bindInt(stmt, index: 6, value: Int32(limit), name: "limit")
        return try collectPathMetadata(stmt: stmt)
    }

    /// Same bbox semantics as the import-level variant, scoped to a single
    /// day. Reads only path metadata.
    public func pathMetadata(
        forDayId dayId: String,
        viewportMinLat: Double, viewportMinLon: Double,
        viewportMaxLat: Double, viewportMaxLon: Double,
        limit: Int
    ) throws -> [LocalTimelinePathRecord] {
        let sql = """
        SELECT id, day_id, start_time, end_time, mode, distance_m,
               point_count, min_lat, min_lon, max_lat, max_lon, coord_encoding
        FROM paths
        WHERE day_id = ?
          AND (min_lat IS NULL OR max_lat IS NULL
               OR min_lon IS NULL OR max_lon IS NULL
               OR (max_lat >= ? AND min_lat <= ?
                   AND max_lon >= ? AND min_lon <= ?))
        ORDER BY start_time IS NULL, start_time
        LIMIT ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")
        try bindDouble(stmt, index: 2, value: viewportMinLat, name: "vp_min_lat")
        try bindDouble(stmt, index: 3, value: viewportMaxLat, name: "vp_max_lat")
        try bindDouble(stmt, index: 4, value: viewportMinLon, name: "vp_min_lon")
        try bindDouble(stmt, index: 5, value: viewportMaxLon, name: "vp_max_lon")
        try bindInt(stmt, index: 6, value: Int32(limit), name: "limit")
        return try collectPathMetadata(stmt: stmt)
    }

    /// Phase-8A bounding box aggregate over `paths.min/max_lat/lon` for a
    /// whole import. Returns `nil` when no path with a non-`NULL` bbox
    /// exists. Reads aggregates only — no `coord_blob` is touched.
    public func pathBoundingBox(forImportId importId: String) throws
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?
    {
        let sql = """
        SELECT MIN(p.min_lat), MIN(p.min_lon), MAX(p.max_lat), MAX(p.max_lon)
        FROM paths AS p
        JOIN days  AS d ON d.id = p.day_id
        WHERE d.import_id = ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        guard let minLat = optionalDoubleColumn(stmt, 0),
              let minLon = optionalDoubleColumn(stmt, 1),
              let maxLat = optionalDoubleColumn(stmt, 2),
              let maxLon = optionalDoubleColumn(stmt, 3) else { return nil }
        return (minLat, minLon, maxLat, maxLon)
    }

    public func pathBoundingBox(forDayId dayId: String) throws
        -> (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?
    {
        let sql = """
        SELECT MIN(min_lat), MIN(min_lon), MAX(max_lat), MAX(max_lon)
        FROM paths WHERE day_id = ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        guard let minLat = optionalDoubleColumn(stmt, 0),
              let minLon = optionalDoubleColumn(stmt, 1),
              let maxLat = optionalDoubleColumn(stmt, 2),
              let maxLon = optionalDoubleColumn(stmt, 3) else { return nil }
        return (minLat, minLon, maxLat, maxLon)
    }

    private func collectPathMetadata(stmt: OpaquePointer?) throws -> [LocalTimelinePathRecord] {
        var out: [LocalTimelinePathRecord] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(LocalTimelinePathRecord(
                id: stringColumn(stmt, 0) ?? "",
                dayId: stringColumn(stmt, 1) ?? "",
                startTime: stringColumn(stmt, 2),
                endTime: stringColumn(stmt, 3),
                mode: stringColumn(stmt, 4),
                distanceM: sqlite3_column_double(stmt, 5),
                pointCount: Int(sqlite3_column_int(stmt, 6)),
                minLat: optionalDoubleColumn(stmt, 7),
                minLon: optionalDoubleColumn(stmt, 8),
                maxLat: optionalDoubleColumn(stmt, 9),
                maxLon: optionalDoubleColumn(stmt, 10),
                coordEncoding: stringColumn(stmt, 11) ?? ""
            ))
        }
        return out
    }

    public func dayDateRange(forImportId importId: String) throws -> (String, String)? {
        let sql = """
        SELECT MIN(date), MAX(date) FROM days WHERE import_id = ?;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        guard let lo = stringColumn(stmt, 0), let hi = stringColumn(stmt, 1) else {
            return nil
        }
        return (lo, hi)
    }

    public func totalDistance(forImportId importId: String) throws -> Double {
        let sql = "SELECT COALESCE(SUM(distance_m), 0) FROM days WHERE import_id = ?;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return sqlite3_column_double(stmt, 0)
    }

    public func totalRouteCount(forImportId importId: String) throws -> Int {
        try sumIntColumn("route_count", importId: importId)
    }

    public func totalVisitCount(forImportId importId: String) throws -> Int {
        try sumIntColumn("visit_count", importId: importId)
    }

    private func sumIntColumn(_ col: String, importId: String) throws -> Int {
        // `col` is a fixed-string call site; not bindable.
        let sql = "SELECT COALESCE(SUM(\(col)), 0) FROM days WHERE import_id = ?;"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    public func days(forImportId importId: String) throws -> [DayRow] {
        let sql = """
        SELECT id, import_id, date, route_count, visit_count, distance_m
        FROM days WHERE import_id = ? ORDER BY date;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: importId, name: "import_id")
        var out: [DayRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(DayRow(
                id: stringColumn(stmt, 0) ?? "",
                importId: stringColumn(stmt, 1) ?? "",
                date: stringColumn(stmt, 2) ?? "",
                routeCount: Int(sqlite3_column_int(stmt, 3)),
                visitCount: Int(sqlite3_column_int(stmt, 4)),
                distanceM: sqlite3_column_double(stmt, 5)
            ))
        }
        return out
    }

    public func visits(forDayId dayId: String) throws -> [VisitRow] {
        let sql = """
        SELECT id, day_id, start_time, end_time, latitude, longitude,
               name, semantic_type, place_id, probability
        FROM visits WHERE day_id = ? ORDER BY start_time;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")
        var out: [VisitRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(VisitRow(
                id: stringColumn(stmt, 0) ?? "",
                dayId: stringColumn(stmt, 1) ?? "",
                startTime: stringColumn(stmt, 2),
                endTime: stringColumn(stmt, 3),
                latitude: optionalDoubleColumn(stmt, 4),
                longitude: optionalDoubleColumn(stmt, 5),
                name: stringColumn(stmt, 6),
                semanticType: stringColumn(stmt, 7),
                placeId: stringColumn(stmt, 8),
                probability: optionalDoubleColumn(stmt, 9)
            ))
        }
        return out
    }

    public func activities(forDayId dayId: String) throws -> [ActivityRow] {
        let sql = """
        SELECT id, day_id, start_time, end_time, mode, distance_m,
               start_lat, start_lon, end_lat, end_lon, probability, raw_type
        FROM activities WHERE day_id = ? ORDER BY start_time;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")
        var out: [ActivityRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(ActivityRow(
                id: stringColumn(stmt, 0) ?? "",
                dayId: stringColumn(stmt, 1) ?? "",
                startTime: stringColumn(stmt, 2),
                endTime: stringColumn(stmt, 3),
                mode: stringColumn(stmt, 4),
                distanceM: optionalDoubleColumn(stmt, 5),
                startLat: optionalDoubleColumn(stmt, 6),
                startLon: optionalDoubleColumn(stmt, 7),
                endLat: optionalDoubleColumn(stmt, 8),
                endLon: optionalDoubleColumn(stmt, 9),
                probability: optionalDoubleColumn(stmt, 10),
                rawType: stringColumn(stmt, 11)
            ))
        }
        return out
    }

    public func paths(forDayId dayId: String) throws -> [PathRow] {
        let sql = """
        SELECT id, day_id, start_time, end_time, mode, distance_m, point_count,
               min_lat, min_lon, max_lat, max_lon, coord_encoding, coord_blob
        FROM paths WHERE day_id = ? ORDER BY start_time;
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: dayId, name: "day_id")

        var out: [PathRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
            out.append(readPathRow(stmt))
        }
        return out
    }

    private func readPathRow(_ stmt: OpaquePointer?) -> PathRow {
        PathRow(
            id: stringColumn(stmt, 0) ?? "",
            dayId: stringColumn(stmt, 1) ?? "",
            startTime: stringColumn(stmt, 2),
            endTime: stringColumn(stmt, 3),
            mode: stringColumn(stmt, 4),
            distanceM: sqlite3_column_double(stmt, 5),
            pointCount: Int(sqlite3_column_int(stmt, 6)),
            minLat: optionalDoubleColumn(stmt, 7),
            minLon: optionalDoubleColumn(stmt, 8),
            maxLat: optionalDoubleColumn(stmt, 9),
            maxLon: optionalDoubleColumn(stmt, 10),
            coordEncoding: stringColumn(stmt, 11) ?? "",
            coordBlob: blobColumn(stmt, 12) ?? Data()
        )
    }

    // MARK: - WAL Checkpoint (P1-C)

    /// Checkpoint modes mirror SQLite's `SQLITE_CHECKPOINT_*` constants.
    /// `truncate` is the bevorzugter Cleanup nach Imports/Delete/Cancel: es
    /// schreibt alle WAL-Frames in die Hauptdatei zurück und kürzt das
    /// `-wal`-File auf 0 Byte, sofern keine Reader die Datei halten.
    public enum WALCheckpointMode: Int32 {
        case passive  = 0  // SQLITE_CHECKPOINT_PASSIVE
        case full     = 1  // SQLITE_CHECKPOINT_FULL
        case restart  = 2  // SQLITE_CHECKPOINT_RESTART
        case truncate = 3  // SQLITE_CHECKPOINT_TRUNCATE
    }

    public struct WALCheckpointInfo: Equatable {
        /// Anzahl Frames im WAL vor dem Checkpoint (`pnLog`).
        public let framesInLog: Int32
        /// Anzahl Frames, die in die Hauptdatei zurückgeschrieben wurden
        /// (`pnCkpt`). Beide sind `-1`, wenn das WAL nicht aktiv ist.
        public let framesCheckpointed: Int32
    }

    /// Run `PRAGMA wal_checkpoint`/`sqlite3_wal_checkpoint_v2` in the given
    /// mode. Idempotent; safe to call on an empty DB. Throws on hard SQLite
    /// errors (`stepFailed`-style). Logical "checkpoint busy" responses
    /// (`SQLITE_BUSY`) are surfaced as `checkpointFailed` so callers can
    /// decide whether to retry or treat as best-effort.
    @discardableResult
    public func checkpointWAL(mode: WALCheckpointMode = .truncate) throws -> WALCheckpointInfo {
        guard let db else { throw LocalTimelineStoreError.notOpen }
        var nLog: Int32 = -1
        var nCkpt: Int32 = -1
        let rc = sqlite3_wal_checkpoint_v2(db, nil, mode.rawValue, &nLog, &nCkpt)
        if rc != SQLITE_OK {
            let msg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            throw LocalTimelineStoreError.checkpointFailed(code: rc, message: msg)
        }
        return WALCheckpointInfo(framesInLog: nLog, framesCheckpointed: nCkpt)
    }

    /// Convenience: `checkpointWAL(mode: .truncate)`.
    @discardableResult
    public func truncateWAL() throws -> WALCheckpointInfo {
        try checkpointWAL(mode: .truncate)
    }

    /// Best-effort cleanup: same as `truncateWAL()` aber wirft nicht. Wird
    /// nach Import/Cancel/Delete aufgerufen, weil ein dort fehlschlagender
    /// Checkpoint den eigentlichen Vorgang nicht zerstören soll.
    @discardableResult
    public func bestEffortTruncateWAL() -> WALCheckpointInfo? {
        try? truncateWAL()
    }

    // MARK: - Low-level helpers

    private func countRows(in table: String) throws -> Int {
        // Table names cannot be parameter-bound; this is a fixed-string call site.
        let sql = "SELECT COUNT(*) FROM \(table);"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else { throw stepError(rc: rc) }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func exec(_ sql: String) throws { try execRaw(sql) }

    /// Internal so `LocalTimelineImportWriter` can drive its own transaction
    /// (BEGIN/COMMIT/ROLLBACK) without re-implementing the C-API plumbing.
    func execRaw(_ sql: String) throws {
        guard let db else { throw LocalTimelineStoreError.notOpen }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw LocalTimelineStoreError.execFailed(sql: sql, code: rc, message: msg)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        guard let db else { throw LocalTimelineStoreError.notOpen }
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK else {
            let msg = sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
            throw LocalTimelineStoreError.prepareFailed(sql: sql, code: rc, message: msg)
        }
        return stmt
    }

    private func stepError(rc: Int32) -> LocalTimelineStoreError {
        let msg = db.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "unknown"
        return .stepFailed(code: rc, message: msg)
    }

    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String, name: String) throws {
        let rc = sqlite3_bind_text(stmt, index, value, -1, Self.SQLITE_TRANSIENT)
        if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?, name: String) throws {
        if let value {
            try bindText(stmt, index: index, value: value, name: name)
        } else {
            let rc = sqlite3_bind_null(stmt, index)
            if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
        }
    }

    private func bindInt(_ stmt: OpaquePointer?, index: Int32, value: Int32, name: String) throws {
        let rc = sqlite3_bind_int(stmt, index, value)
        if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
    }

    private func bindDouble(_ stmt: OpaquePointer?, index: Int32, value: Double, name: String) throws {
        let rc = sqlite3_bind_double(stmt, index, value)
        if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
    }

    private func bindOptionalDouble(_ stmt: OpaquePointer?, index: Int32, value: Double?, name: String) throws {
        if let value {
            try bindDouble(stmt, index: index, value: value, name: name)
        } else {
            let rc = sqlite3_bind_null(stmt, index)
            if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
        }
    }

    private func bindBlob(_ stmt: OpaquePointer?, index: Int32, value: Data, name: String) throws {
        // sqlite3_bind_zeroblob handles the empty case more cleanly than passing
        // a possibly-dangling pointer derived from an empty Data buffer.
        if value.isEmpty {
            let rc = sqlite3_bind_zeroblob(stmt, index, 0)
            if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
            return
        }
        let rc = value.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int32 in
            sqlite3_bind_blob(stmt, index, buffer.baseAddress, Int32(buffer.count), Self.SQLITE_TRANSIENT)
        }
        if rc != SQLITE_OK { throw LocalTimelineStoreError.bindFailed(parameter: name, code: rc) }
    }

    private func stringColumn(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }

    private func optionalDoubleColumn(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        return sqlite3_column_double(stmt, index)
    }

    private func blobColumn(_ stmt: OpaquePointer?, _ index: Int32) -> Data? {
        let byteCount = Int(sqlite3_column_bytes(stmt, index))
        if byteCount == 0 { return Data() }
        guard let raw = sqlite3_column_blob(stmt, index) else { return nil }
        return Data(bytes: raw, count: byteCount)
    }
}
