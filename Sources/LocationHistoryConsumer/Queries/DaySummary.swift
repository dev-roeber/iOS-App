import Foundation

public struct DaySummary: Equatable {
    public let date: String
    public let visitCount: Int
    public let activityCount: Int
    public let pathCount: Int
    public let totalPathPointCount: Int
    public let totalPathDistanceM: Double
}
