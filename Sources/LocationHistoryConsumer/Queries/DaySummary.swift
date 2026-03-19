import Foundation

public struct DaySummary: Equatable {
    public let date: String
    public let visitCount: Int
    public let activityCount: Int
    public let pathCount: Int
    public let totalPathPointCount: Int
    public let totalPathDistanceM: Double
    public let hasContent: Bool
    public let exportablePathCount: Int

    public init(
        date: String,
        visitCount: Int,
        activityCount: Int,
        pathCount: Int,
        totalPathPointCount: Int,
        totalPathDistanceM: Double,
        hasContent: Bool,
        exportablePathCount: Int? = nil
    ) {
        self.date = date
        self.visitCount = visitCount
        self.activityCount = activityCount
        self.pathCount = pathCount
        self.totalPathPointCount = totalPathPointCount
        self.totalPathDistanceM = totalPathDistanceM
        self.hasContent = hasContent
        self.exportablePathCount = exportablePathCount ?? pathCount
    }
}
