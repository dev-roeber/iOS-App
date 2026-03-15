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
        public let distanceM: Double?
        public let pointCount: Int
        public let sourceType: String?
        public let points: [PathPointItem]
    }

    public struct PathPointItem: Equatable {
        public let lat: Double
        public let lon: Double
        public let time: String?
        public let accuracyM: Double?
    }
}
