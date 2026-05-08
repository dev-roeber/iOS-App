import Foundation

public struct DayDetailViewState: Equatable {
    public let date: String
    public let visits: [VisitItem]
    public let activities: [ActivityItem]
    public let paths: [PathItem]
    public let totalPathPointCount: Int
    public let hasContent: Bool

    public struct VisitItem: Equatable {
        public let startTime: String?
        public let endTime: String?
        public let semanticType: String?
        public let placeID: String?
        public let lat: Double?
        public let lon: Double?
        public let accuracyM: Double?
        public let sourceType: String?
    }

    public struct ActivityItem: Equatable {
        public let startTime: String?
        public let endTime: String?
        public let activityType: String?
        public let distanceM: Double?
        public let splitFromMidnight: Bool?
        public let startLat: Double?
        public let startLon: Double?
        public let endLat: Double?
        public let endLon: Double?
        public let sourceType: String?
    }

    public struct PathItem: Equatable {
        public let startTime: String?
        public let endTime: String?
        public let activityType: String?
        /// Raw `distanceM` as reported by the exporter. May be `nil` or
        /// non-finite for sources that emit only geometry (Google Timeline
        /// `timelinePath` is the typical case). Day-detail UI must read
        /// `effectiveDistanceM` instead so summary and detail agree.
        public let distanceM: Double?
        /// Effective distance in metres. Equal to `distanceM` when that is
        /// finite and `> 0`; otherwise reconstructed from `points` or
        /// `flatCoordinates` via `PathDistanceCalculator`. Always
        /// non-negative; `0` only when no usable geometry is available.
        public let effectiveDistanceM: Double
        public let pointCount: Int
        public let sourceType: String?
        public let points: [PathPointItem]
        /// Optional compact lat/lon array — even-count `[lat0, lon0, lat1, lon1, …]`.
        /// When the importer chooses the flat representation (Google Timeline
        /// after the 2026-05-08 P0 refactor), `points` may be empty and
        /// `flatCoordinates` carries the full geometry. Consumers that walk
        /// path geometry (map overlays, exporters) must accept either.
        public let flatCoordinates: [Double]?

        public init(
            startTime: String?,
            endTime: String?,
            activityType: String?,
            distanceM: Double?,
            effectiveDistanceM: Double,
            pointCount: Int,
            sourceType: String?,
            points: [PathPointItem],
            flatCoordinates: [Double]? = nil
        ) {
            self.startTime = startTime
            self.endTime = endTime
            self.activityType = activityType
            self.distanceM = distanceM
            self.effectiveDistanceM = effectiveDistanceM
            self.pointCount = pointCount
            self.sourceType = sourceType
            self.points = points
            self.flatCoordinates = flatCoordinates
        }
    }

    public struct PathPointItem: Equatable {
        public let lat: Double
        public let lon: Double
        public let time: String?
        public let accuracyM: Double?
    }
}
