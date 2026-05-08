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

    // MARK: - Read API

    public func countImports() throws -> Int { try countRows(in: "imports") }
    public func countDays() throws -> Int { try countRows(in: "days") }
    public func countPaths() throws -> Int { try countRows(in: "paths") }

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

    private func exec(_ sql: String) throws {
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
