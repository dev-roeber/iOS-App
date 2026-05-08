import Foundation
import LocationHistoryConsumer

/// Phase-3 read-models for the LocalTimelineStore.
///
/// These types are intentionally Foundation-only: they expose disk rows in a
/// shape that DayList / DayDetail / Map preparation can read without pulling
/// in SwiftUI, MapKit, or any `AppExport` symbol. They are **not** the
/// persistence row structs (`ImportRow`/`DayRow`/...) — those stay close to
/// the SQLite layer; the read-models below carry only the fields a UI-bound
/// reader consumer cares about and are the surface other layers should
/// program against.
///
/// Bounded-read invariant: none of these read-models carry a decoded
/// `[Double]` of path coordinates. Coordinates are reachable only via
/// `LocalTimelineStoreReader.coordinateSequence(forPathId:)`, which returns a
/// `CoordBlobIterator` that decodes lazily.

public struct LocalTimelineImportRecord: Equatable {
    public let id: String
    public let sourceFilename: String
    public let createdAt: String
    public init(id: String, sourceFilename: String, createdAt: String) {
        self.id = id
        self.sourceFilename = sourceFilename
        self.createdAt = createdAt
    }
}

public struct LocalTimelineDayRecord: Equatable {
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

public struct LocalTimelineVisitRecord: Equatable {
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

public struct LocalTimelineActivityRecord: Equatable {
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

/// Path **metadata** only — no coordinate blob is held here. Decoding is
/// done explicitly via `LocalTimelineStoreReader.coordinateSequence(forPathId:)`.
public struct LocalTimelinePathRecord: Equatable {
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
    public init(id: String, dayId: String,
                startTime: String?, endTime: String?,
                mode: String?, distanceM: Double, pointCount: Int,
                minLat: Double?, minLon: Double?,
                maxLat: Double?, maxLon: Double?,
                coordEncoding: String) {
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
    }
}

/// Bounded snapshot for a single day. Carries the day summary plus the
/// child collections (visits / activities / path **metadata**) ordered by
/// `start_time`. **No path coordinates are decoded eagerly** — callers walk
/// `paths[i]` and request the iterator separately if they need geometry.
public struct LocalTimelineDayDetailSnapshot: Equatable {
    public let day: LocalTimelineDayRecord
    public let visits: [LocalTimelineVisitRecord]
    public let activities: [LocalTimelineActivityRecord]
    public let paths: [LocalTimelinePathRecord]
    public init(day: LocalTimelineDayRecord,
                visits: [LocalTimelineVisitRecord],
                activities: [LocalTimelineActivityRecord],
                paths: [LocalTimelinePathRecord]) {
        self.day = day
        self.visits = visits
        self.activities = activities
        self.paths = paths
    }
}
