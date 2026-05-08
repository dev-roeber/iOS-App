import Foundation

/// Schema for the LocalTimelineStore SQLite spike.
///
/// Phase 1 (`user_version = 1`) introduced `imports`, `days`, `paths`.
/// Phase 2 (`user_version = 2`) adds `visits`, `activities` and a few
/// composite/secondary indices. All `CREATE TABLE` and `CREATE INDEX`
/// statements use `IF NOT EXISTS`, so applying the bootstrap list to a
/// pristine v1 database upgrades it idempotently. The migration is
/// additive — no v1 row is rewritten — and `PRAGMA user_version` is set
/// to `userVersion` after every successful bootstrap pass.
///
/// `derived_cache`, `path_bounds` (RTree) remain deferred — see
/// `docs/LOCAL_TIMELINE_STORE_RESEARCH.md`.
///
/// The schema is not yet a contract.
public enum LocalTimelineStoreSchema {
    /// Bumped only when the on-disk shape changes.
    public static let userVersion: Int32 = 2

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

    public static let createVisitsSQL = """
    CREATE TABLE IF NOT EXISTS visits (
        id            TEXT PRIMARY KEY,
        day_id        TEXT NOT NULL,
        start_time    TEXT,
        end_time      TEXT,
        latitude      REAL,
        longitude     REAL,
        name          TEXT,
        semantic_type TEXT,
        place_id      TEXT,
        probability   REAL,
        FOREIGN KEY(day_id) REFERENCES days(id) ON DELETE CASCADE
    );
    """

    public static let createActivitiesSQL = """
    CREATE TABLE IF NOT EXISTS activities (
        id          TEXT PRIMARY KEY,
        day_id      TEXT NOT NULL,
        start_time  TEXT,
        end_time    TEXT,
        mode        TEXT,
        distance_m  REAL,
        start_lat   REAL,
        start_lon   REAL,
        end_lat     REAL,
        end_lon     REAL,
        probability REAL,
        raw_type    TEXT,
        FOREIGN KEY(day_id) REFERENCES days(id) ON DELETE CASCADE
    );
    """

    public static let createIndexDaysImportSQL = """
    CREATE INDEX IF NOT EXISTS idx_days_import_id ON days(import_id);
    """

    public static let createIndexDaysDateSQL = """
    CREATE INDEX IF NOT EXISTS idx_days_date ON days(date);
    """

    public static let createIndexDaysImportDateSQL = """
    CREATE INDEX IF NOT EXISTS idx_days_import_date ON days(import_id, date);
    """

    public static let createIndexPathsDaySQL = """
    CREATE INDEX IF NOT EXISTS idx_paths_day_id ON paths(day_id);
    """

    public static let createIndexPathsDayStartSQL = """
    CREATE INDEX IF NOT EXISTS idx_paths_day_start ON paths(day_id, start_time);
    """

    public static let createIndexVisitsDaySQL = """
    CREATE INDEX IF NOT EXISTS idx_visits_day_id ON visits(day_id);
    """

    public static let createIndexActivitiesDaySQL = """
    CREATE INDEX IF NOT EXISTS idx_activities_day_id ON activities(day_id);
    """

    public static let allBootstrapStatements: [String] = [
        createImportsSQL,
        createDaysSQL,
        createPathsSQL,
        createVisitsSQL,
        createActivitiesSQL,
        createIndexDaysImportSQL,
        createIndexDaysDateSQL,
        createIndexDaysImportDateSQL,
        createIndexPathsDaySQL,
        createIndexPathsDayStartSQL,
        createIndexVisitsDaySQL,
        createIndexActivitiesDaySQL,
    ]
}

// MARK: - Row structs

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

public struct VisitRow: Equatable {
    public let id: String
    public let dayId: String
    public let startTime: String?
    public let endTime: String?
    public let latitude: Double?
    public let longitude: Double?
    public let name: String?
    public let semanticType: String?
    public let placeId: String?
    public let probability: Double?
    public init(id: String, dayId: String,
                startTime: String?, endTime: String?,
                latitude: Double?, longitude: Double?,
                name: String?, semanticType: String?,
                placeId: String?, probability: Double?) {
        self.id = id
        self.dayId = dayId
        self.startTime = startTime
        self.endTime = endTime
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.semanticType = semanticType
        self.placeId = placeId
        self.probability = probability
    }
}

public struct ActivityRow: Equatable {
    public let id: String
    public let dayId: String
    public let startTime: String?
    public let endTime: String?
    public let mode: String?
    public let distanceM: Double?
    public let startLat: Double?
    public let startLon: Double?
    public let endLat: Double?
    public let endLon: Double?
    public let probability: Double?
    public let rawType: String?
    public init(id: String, dayId: String,
                startTime: String?, endTime: String?,
                mode: String?, distanceM: Double?,
                startLat: Double?, startLon: Double?,
                endLat: Double?, endLon: Double?,
                probability: Double?, rawType: String?) {
        self.id = id
        self.dayId = dayId
        self.startTime = startTime
        self.endTime = endTime
        self.mode = mode
        self.distanceM = distanceM
        self.startLat = startLat
        self.startLon = startLon
        self.endLat = endLat
        self.endLon = endLon
        self.probability = probability
        self.rawType = rawType
    }
}
