import Foundation

public struct DayMapCoordinate: Equatable {
    public let lat: Double
    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public struct DayMapRegion: Equatable {
    public let centerLat: Double
    public let centerLon: Double
    public let spanLat: Double
    public let spanLon: Double

    public init(centerLat: Double, centerLon: Double, spanLat: Double, spanLon: Double) {
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.spanLat = spanLat
        self.spanLon = spanLon
    }
}

public struct DayMapVisitAnnotation: Equatable {
    public let coordinate: DayMapCoordinate
    public let semanticType: String?
    public let startTime: String?
    public let endTime: String?

    public init(
        coordinate: DayMapCoordinate,
        semanticType: String?,
        startTime: String?,
        endTime: String?
    ) {
        self.coordinate = coordinate
        self.semanticType = semanticType
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct DayMapPathOverlay: Equatable {
    public let coordinates: [DayMapCoordinate]
    public let activityType: String?
    public let distanceM: Double?
    /// Optional ISO-8601 timestamps parallel to `coordinates`. When present
    /// they enable speed-coloured rendering ("Tempolayer"). May be empty.
    public let timestamps: [String?]

    public init(
        coordinates: [DayMapCoordinate],
        activityType: String?,
        distanceM: Double?,
        timestamps: [String?] = []
    ) {
        self.coordinates = coordinates
        self.activityType = activityType
        self.distanceM = distanceM
        self.timestamps = timestamps
    }
}

public struct DayMapData: Equatable {
    public let visitAnnotations: [DayMapVisitAnnotation]
    public let pathOverlays: [DayMapPathOverlay]
    public let fittedRegion: DayMapRegion?
    public let hasMapContent: Bool

    public init(
        visitAnnotations: [DayMapVisitAnnotation],
        pathOverlays: [DayMapPathOverlay],
        fittedRegion: DayMapRegion?,
        hasMapContent: Bool
    ) {
        self.visitAnnotations = visitAnnotations
        self.pathOverlays = pathOverlays
        self.fittedRegion = fittedRegion
        self.hasMapContent = hasMapContent
    }
}

public enum DayMapDataExtractor {

    public static func mapData(from detail: DayDetailViewState) -> DayMapData {
        let visitAnnotations = detail.visits.compactMap { visit -> DayMapVisitAnnotation? in
            guard let lat = visit.lat, let lon = visit.lon else { return nil }
            return DayMapVisitAnnotation(
                coordinate: DayMapCoordinate(lat: lat, lon: lon),
                semanticType: visit.semanticType,
                startTime: visit.startTime,
                endTime: visit.endTime
            )
        }

        let pathOverlays = detail.paths.compactMap { path -> DayMapPathOverlay? in
            let coords = path.points.map { DayMapCoordinate(lat: $0.lat, lon: $0.lon) }
            let timestamps = path.points.map { $0.time }
            guard coords.count >= 2 else { return nil }
            return DayMapPathOverlay(
                coordinates: coords,
                activityType: path.activityType,
                distanceM: path.distanceM,
                timestamps: timestamps
            )
        }

        let allCoordinates = visitAnnotations.map(\.coordinate)
            + pathOverlays.flatMap(\.coordinates)
        let fittedRegion = computeRegion(from: allCoordinates)

        return DayMapData(
            visitAnnotations: visitAnnotations,
            pathOverlays: pathOverlays,
            fittedRegion: fittedRegion,
            hasMapContent: !visitAnnotations.isEmpty || !pathOverlays.isEmpty
        )
    }

    static func computeRegion(from coordinates: [DayMapCoordinate]) -> DayMapRegion? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.lat
        var maxLat = first.lat
        var minLon = first.lon
        var maxLon = first.lon

        for coord in coordinates {
            minLat = min(minLat, coord.lat)
            maxLat = max(maxLat, coord.lat)
            minLon = min(minLon, coord.lon)
            maxLon = max(maxLon, coord.lon)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.005)
        let spanLon = max((maxLon - minLon) * 1.4, 0.005)

        return DayMapRegion(
            centerLat: centerLat,
            centerLon: centerLon,
            spanLat: spanLat,
            spanLon: spanLon
        )
    }
}
