import Foundation

/// Phase-1 minimal schema for the LocalTimelineStore SQLite spike.
///
/// Only `imports`, `days`, `paths` are part of this spike. `visits`,
/// `activities`, `derived_cache`, `path_bounds` (RTree) are deferred to
/// later phases — see `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.
///
/// The schema is not yet a contract. The plan tracks `PRAGMA user_version`
/// so a future phase can introduce migrations without rebuilding the file.
public enum LocalTimelineStoreSchema {
    /// Bumped only when the on-disk shape changes.
    public static let userVersion: Int32 = 1

    public static let createImportsSQL = """
    CREATE TABLE IF NOT EXISTS imports (
        id              TEXT    PRIMARY KEY,
        source_filename TEXT    NOT NULL,
        created_at      TEXT    NOT NULL
    );
    """

    public static let createDaysSQL = """
    CREATE TABLE IF NOT EXISTS days (
        id           TEXT    PRIMARY KEY,
        import_id    TEXT    NOT NULL,
        date         TEXT    NOT NULL,
        route_count  INTEGER NOT NULL DEFAULT 0,
        visit_count  INTEGER NOT NULL DEFAULT 0,
        distance_m   REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY(import_id) REFERENCES imports(id) ON DELETE CASCADE
    );
    """

    public static let createPathsSQL = """
    CREATE TABLE IF NOT EXISTS paths (
        id             TEXT    PRIMARY KEY,
        day_id         TEXT    NOT NULL,
        start_time     TEXT,
        end_time       TEXT,
        mode           TEXT,
        distance_m     REAL    NOT NULL DEFAULT 0,
        point_count    INTEGER NOT NULL DEFAULT 0,
        min_lat        REAL,
        min_lon        REAL,
        max_lat        REAL,
        max_lon        REAL,
        coord_encoding TEXT    NOT NULL,
        coord_blob     BLOB    NOT NULL,
        FOREIGN KEY(day_id) REFERENCES days(id) ON DELETE CASCADE
    );
    """

    public static let createIndexDaysImportSQL = """
    CREATE INDEX IF NOT EXISTS idx_days_import_id ON days(import_id);
    """

    public static let createIndexDaysDateSQL = """
    CREATE INDEX IF NOT EXISTS idx_days_date ON days(date);
    """

    public static let createIndexPathsDaySQL = """
    CREATE INDEX IF NOT EXISTS idx_paths_day_id ON paths(day_id);
    """

    public static let allBootstrapStatements: [String] = [
        createImportsSQL,
        createDaysSQL,
        createPathsSQL,
        createIndexDaysImportSQL,
        createIndexDaysDateSQL,
        createIndexPathsDaySQL,
    ]
}

/// Plain row structs for the spike. Production queries will project lazily;
/// these are convenience for the Linux test path.
public struct ImportRow: Equatable {
    public let id: String
    public let sourceFilename: String
    public let createdAt: String
    public init(id: String, sourceFilename: String, createdAt: String) {
        self.id = id
        self.sourceFilename = sourceFilename
        self.createdAt = createdAt
    }
}

public struct DayRow: Equatable {
    public let id: String
    public let importId: String
    public let date: String
    public let routeCount: Int
    public let visitCount: Int
    public let distanceM: Double
    public init(id: String, importId: String, date: String,
                routeCount: Int, visitCount: Int, distanceM: Double) {
        self.id = id
        self.importId = importId
        self.date = date
        self.routeCount = routeCount
        self.visitCount = visitCount
        self.distanceM = distanceM
    }
}

public struct PathRow: Equatable {
    public let id: String
    public let dayId: String
    public let startTime: String?
    public let endTime: String?
    public let mode: String?
    public let distanceM: Double
    public let pointCount: Int
    public let minLat: Double?
    public let minLon: Double?
    public let maxLat: Double?
    public let maxLon: Double?
    public let coordEncoding: String
    public let coordBlob: Data
    public init(id: String, dayId: String,
                startTime: String?, endTime: String?,
                mode: String?, distanceM: Double, pointCount: Int,
                minLat: Double?, minLon: Double?,
                maxLat: Double?, maxLon: Double?,
                coordEncoding: String, coordBlob: Data) {
        self.id = id
        self.dayId = dayId
        self.startTime = startTime
        self.endTime = endTime
        self.mode = mode
        self.distanceM = distanceM
        self.pointCount = pointCount
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
        self.coordEncoding = coordEncoding
        self.coordBlob = coordBlob
    }
}
