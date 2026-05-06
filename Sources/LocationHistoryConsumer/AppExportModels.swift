import Foundation

public enum AppExportSchemaVersion: String, Codable {
    case v1_0 = "1.0"
}

public struct AppExport: Codable {
    public let schemaVersion: AppExportSchemaVersion
    public let meta: Meta
    public let data: DataBlock
    public let stats: Stats?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case meta
        case data
        case stats
    }

    public init(schemaVersion: AppExportSchemaVersion, meta: Meta, data: DataBlock, stats: Stats?) {
        self.schemaVersion = schemaVersion
        self.meta = meta
        self.data = data
        self.stats = stats
    }
}

public struct Meta: Codable {
    public let exportedAt: String
    public let toolVersion: String
    public let source: Source
    public let output: Output
    public let config: ExportConfig
    public let filters: ExportFilters

    enum CodingKeys: String, CodingKey {
        case exportedAt = "exported_at"
        case toolVersion = "tool_version"
        case source
        case output
        case config
        case filters
    }

    public init(
        exportedAt: String,
        toolVersion: String,
        source: Source,
        output: Output,
        config: ExportConfig,
        filters: ExportFilters
    ) {
        self.exportedAt = exportedAt
        self.toolVersion = toolVersion
        self.source = source
        self.output = output
        self.config = config
        self.filters = filters
    }
}

public struct Source: Codable {
    public let zipBasename: String?
    public let zipPath: String?
    public let inputFormat: String?

    enum CodingKeys: String, CodingKey {
        case zipBasename = "zip_basename"
        case zipPath = "zip_path"
        case inputFormat = "input_format"
    }

    public init(zipBasename: String?, zipPath: String?, inputFormat: String?) {
        self.zipBasename = zipBasename
        self.zipPath = zipPath
        self.inputFormat = inputFormat
    }
}

public struct Output: Codable {
    public let outDir: String?

    enum CodingKeys: String, CodingKey {
        case outDir = "out_dir"
    }

    public init(outDir: String?) {
        self.outDir = outDir
    }
}

public struct ExportConfig: Codable {
    public let mode: String?
    public let splitMidnight: String?
    public let splitMode: String?
    public let exportFormat: [String]?
    public let inputFormat: String?

    enum CodingKeys: String, CodingKey {
        case mode
        case splitMidnight = "split_midnight"
        case splitMode = "split_mode"
        case exportFormat = "export_format"
        case inputFormat = "input_format"
    }

    public init(
        mode: String?,
        splitMidnight: String?,
        splitMode: String?,
        exportFormat: [String]?,
        inputFormat: String?
    ) {
        self.mode = mode
        self.splitMidnight = splitMidnight
        self.splitMode = splitMode
        self.exportFormat = exportFormat
        self.inputFormat = inputFormat
    }
}

public struct ExportFilters: Codable {
    public let fromDate: String?
    public let toDate: String?
    public let year: Int?
    public let month: Int?
    public let weekday: Int?
    public let limit: Int?
    public let days: [String]?
    public let has: [String]?
    public let maxAccuracyM: Double?
    public let activityTypes: [String]?
    public let minGapMin: Int?

    enum CodingKeys: String, CodingKey {
        case fromDate = "from_date"
        case toDate = "to_date"
        case year
        case month
        case weekday
        case limit
        case days
        case has
        case maxAccuracyM = "max_accuracy_m"
        case activityTypes = "activity_types"
        case minGapMin = "min_gap_min"
    }

    public init(
        fromDate: String?,
        toDate: String?,
        year: Int?,
        month: Int?,
        weekday: Int?,
        limit: Int?,
        days: [String]?,
        has: [String]?,
        maxAccuracyM: Double?,
        activityTypes: [String]?,
        minGapMin: Int?
    ) {
        self.fromDate = fromDate
        self.toDate = toDate
        self.year = year
        self.month = month
        self.weekday = weekday
        self.limit = limit
        self.days = days
        self.has = has
        self.maxAccuracyM = maxAccuracyM
        self.activityTypes = activityTypes
        self.minGapMin = minGapMin
    }
}

public struct DataBlock: Codable {
    public let days: [Day]

    public init(days: [Day]) {
        self.days = days
    }
}

public struct Day: Codable {
    public let date: String
    public let visits: [Visit]
    public let activities: [Activity]
    public let paths: [Path]

    public init(
        date: String,
        visits: [Visit],
        activities: [Activity],
        paths: [Path]
    ) {
        self.date = date
        self.visits = visits
        self.activities = activities
        self.paths = paths
    }
}

public struct Visit: Codable {
    public let lat: Double?
    public let lon: Double?
    public let startTime: String?
    public let endTime: String?
    public let semanticType: String?
    public let placeID: String?
    public let accuracyM: Double?
    public let sourceType: String?

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case startTime = "start_time"
        case endTime = "end_time"
        case semanticType = "semantic_type"
        case placeID = "place_id"
        case accuracyM = "accuracy_m"
        case sourceType = "source_type"
    }

    public init(
        lat: Double?,
        lon: Double?,
        startTime: String?,
        endTime: String?,
        semanticType: String?,
        placeID: String?,
        accuracyM: Double?,
        sourceType: String?
    ) {
        self.lat = lat
        self.lon = lon
        self.startTime = startTime
        self.endTime = endTime
        self.semanticType = semanticType
        self.placeID = placeID
        self.accuracyM = accuracyM
        self.sourceType = sourceType
    }
}

public struct Activity: Codable {
    public let startTime: String?
    public let endTime: String?
    public let startLat: Double?
    public let startLon: Double?
    public let endLat: Double?
    public let endLon: Double?
    public let activityType: String?
    public let distanceM: Double?
    public let splitFromMidnight: Bool?
    public let startAccuracyM: Double?
    public let endAccuracyM: Double?
    public let sourceType: String?
    public let flatCoordinates: [Double]?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case startLat = "start_lat"
        case startLon = "start_lon"
        case endLat = "end_lat"
        case endLon = "end_lon"
        case activityType = "activity_type"
        case distanceM = "distance_m"
        case splitFromMidnight = "split_from_midnight"
        case startAccuracyM = "start_accuracy_m"
        case endAccuracyM = "end_accuracy_m"
        case sourceType = "source_type"
        case flatCoordinates = "flat_coordinates"
    }

    public init(
        startTime: String?,
        endTime: String?,
        startLat: Double?,
        startLon: Double?,
        endLat: Double?,
        endLon: Double?,
        activityType: String?,
        distanceM: Double?,
        splitFromMidnight: Bool?,
        startAccuracyM: Double?,
        endAccuracyM: Double?,
        sourceType: String?,
        flatCoordinates: [Double]?
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.startLat = startLat
        self.startLon = startLon
        self.endLat = endLat
        self.endLon = endLon
        self.activityType = activityType
        self.distanceM = distanceM
        self.splitFromMidnight = splitFromMidnight
        self.startAccuracyM = startAccuracyM
        self.endAccuracyM = endAccuracyM
        self.sourceType = sourceType
        self.flatCoordinates = flatCoordinates
    }
}

public struct Path: Codable {
    public let startTime: String?
    public let endTime: String?
    public let activityType: String?
    public let distanceM: Double?
    public let sourceType: String?
    public let points: [PathPoint]
    public let flatCoordinates: [Double]?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case activityType = "activity_type"
        case distanceM = "distance_m"
        case sourceType = "source_type"
        case points
        case flatCoordinates = "flat_coordinates"
    }

    public init(
        startTime: String?,
        endTime: String?,
        activityType: String?,
        distanceM: Double?,
        sourceType: String?,
        points: [PathPoint],
        flatCoordinates: [Double]?
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.activityType = activityType
        self.distanceM = distanceM
        self.sourceType = sourceType
        self.points = points
        self.flatCoordinates = flatCoordinates
    }
}

public struct PathPoint: Codable {
    public let lat: Double
    public let lon: Double
    public let time: String?
    public let accuracyM: Double?

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case time
        case accuracyM = "accuracy_m"
    }

    public init(
        lat: Double,
        lon: Double,
        time: String?,
        accuracyM: Double?
    ) {
        self.lat = lat
        self.lon = lon
        self.time = time
        self.accuracyM = accuracyM
    }
}

public struct Stats: Codable {
    public let activities: [String: ActivityStats]?
    public let periods: [PeriodStats]?
}

public struct ActivityStats: Codable {
    public let count: Int
    public let totalDistanceKM: Double
    public let totalDurationH: Double
    public let avgDistanceKM: Double
    public let avgSpeedKMH: Double

    enum CodingKeys: String, CodingKey {
        case count
        case totalDistanceKM = "total_distance_km"
        case totalDurationH = "total_duration_h"
        case avgDistanceKM = "avg_distance_km"
        case avgSpeedKMH = "avg_speed_kmh"
    }
}

public struct PeriodStats: Codable {
    public let label: String
    public let year: Int
    public let month: Int?
    public let days: Int
    public let visits: Int
    public let activities: Int
    public let paths: Int
    public let distanceM: Double

    enum CodingKeys: String, CodingKey {
        case label
        case year
        case month
        case days
        case visits
        case activities
        case paths
        case distanceM = "distance_m"
    }
}
