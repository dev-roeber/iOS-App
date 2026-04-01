import Foundation

public enum AppExportContentRequirement: String, CaseIterable, Equatable, Hashable {
    case visits
    case activities
    case paths
}

public struct ExportCoordinate: Equatable, Hashable {
    public let lat: Double
    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public struct ExportCoordinateBounds: Equatable, Hashable {
    public let minLat: Double
    public let maxLat: Double
    public let minLon: Double
    public let maxLon: Double

    public init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = min(minLat, maxLat)
        self.maxLat = max(minLat, maxLat)
        self.minLon = min(minLon, maxLon)
        self.maxLon = max(minLon, maxLon)
    }

    func contains(_ coordinate: ExportCoordinate) -> Bool {
        coordinate.lat >= minLat &&
        coordinate.lat <= maxLat &&
        coordinate.lon >= minLon &&
        coordinate.lon <= maxLon
    }
}

public indirect enum ExportSpatialFilter: Equatable, Hashable {
    case bounds(ExportCoordinateBounds)
    case polygon([ExportCoordinate])
    case all([ExportSpatialFilter])

    public func contains(lat: Double, lon: Double) -> Bool {
        contains(ExportCoordinate(lat: lat, lon: lon))
    }

    public func contains(_ coordinate: ExportCoordinate) -> Bool {
        switch self {
        case let .bounds(bounds):
            return bounds.contains(coordinate)
        case let .polygon(vertices):
            return Self.pointInPolygon(coordinate, vertices: vertices)
        case let .all(filters):
            return filters.allSatisfy { $0.contains(coordinate) }
        }
    }

    private static func pointInPolygon(_ point: ExportCoordinate, vertices: [ExportCoordinate]) -> Bool {
        guard vertices.count >= 3 else {
            return false
        }

        var isInside = false
        var previous = vertices[vertices.count - 1]

        for current in vertices {
            let intersects = ((current.lat > point.lat) != (previous.lat > point.lat)) &&
            (point.lon < (previous.lon - current.lon) * (point.lat - current.lat) / (previous.lat - current.lat) + current.lon)

            if intersects {
                isInside.toggle()
            }

            previous = current
        }

        return isInside
    }
}

public struct AppExportQueryFilter: Equatable, Hashable {
    public let fromDate: String?
    public let toDate: String?
    public let year: Int?
    public let month: Int?
    public let weekday: Int?
    public let limit: Int?
    public let days: Set<String>
    public let requiredContent: Set<AppExportContentRequirement>
    public let maxAccuracyM: Double?
    public let activityTypes: Set<String>
    public let minGapMin: Int?
    public let spatialFilter: ExportSpatialFilter?

    public init(
        fromDate: String? = nil,
        toDate: String? = nil,
        year: Int? = nil,
        month: Int? = nil,
        weekday: Int? = nil,
        limit: Int? = nil,
        days: Set<String> = [],
        requiredContent: Set<AppExportContentRequirement> = [],
        maxAccuracyM: Double? = nil,
        activityTypes: Set<String> = [],
        minGapMin: Int? = nil,
        spatialFilter: ExportSpatialFilter? = nil
    ) {
        self.fromDate = fromDate
        self.toDate = toDate
        self.year = year
        self.month = month
        self.weekday = weekday
        self.limit = limit
        self.days = days
        self.requiredContent = requiredContent
        self.maxAccuracyM = maxAccuracyM
        self.activityTypes = activityTypes
        self.minGapMin = minGapMin
        self.spatialFilter = spatialFilter
    }

    public init(exportFilters: ExportFilters, spatialFilter: ExportSpatialFilter? = nil) {
        self.init(
            fromDate: exportFilters.fromDate,
            toDate: exportFilters.toDate,
            year: exportFilters.year,
            month: exportFilters.month,
            weekday: exportFilters.weekday,
            limit: exportFilters.limit,
            days: Set(exportFilters.days ?? []),
            requiredContent: Set((exportFilters.has ?? []).compactMap(AppExportContentRequirement.init(rawValue:))),
            maxAccuracyM: exportFilters.maxAccuracyM,
            activityTypes: Set(exportFilters.activityTypes ?? []),
            minGapMin: exportFilters.minGapMin,
            spatialFilter: spatialFilter
        )
    }

    var hasContentConstraint: Bool {
        !requiredContent.isEmpty ||
        maxAccuracyM != nil ||
        !activityTypes.isEmpty ||
        spatialFilter != nil
    }
}
