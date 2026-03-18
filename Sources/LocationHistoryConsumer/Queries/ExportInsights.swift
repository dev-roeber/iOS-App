import Foundation

public struct ExportInsights: Equatable {
    public let dateRange: InsightsDateRange?
    public let totalDistanceM: Double
    public let activityBreakdown: [ActivityBreakdownItem]
    public let visitTypeBreakdown: [VisitTypeItem]
    public let periodBreakdown: [PeriodBreakdownItem]
    public let averagesPerDay: DayAverages
    public let busiestDay: DayHighlight?
    public let longestDistanceDay: DayHighlight?
    public let activeFilterDescriptions: [String]

    public init(
        dateRange: InsightsDateRange?,
        totalDistanceM: Double,
        activityBreakdown: [ActivityBreakdownItem],
        visitTypeBreakdown: [VisitTypeItem],
        periodBreakdown: [PeriodBreakdownItem],
        averagesPerDay: DayAverages,
        busiestDay: DayHighlight? = nil,
        longestDistanceDay: DayHighlight? = nil,
        activeFilterDescriptions: [String] = []
    ) {
        self.dateRange = dateRange
        self.totalDistanceM = totalDistanceM
        self.activityBreakdown = activityBreakdown
        self.visitTypeBreakdown = visitTypeBreakdown
        self.periodBreakdown = periodBreakdown
        self.averagesPerDay = averagesPerDay
        self.busiestDay = busiestDay
        self.longestDistanceDay = longestDistanceDay
        self.activeFilterDescriptions = activeFilterDescriptions
    }
}

public struct DayHighlight: Equatable {
    public let date: String
    public let value: String

    public init(date: String, value: String) {
        self.date = date
        self.value = value
    }
}

public struct InsightsDateRange: Equatable {
    public let firstDate: String
    public let lastDate: String

    public init(firstDate: String, lastDate: String) {
        self.firstDate = firstDate
        self.lastDate = lastDate
    }
}

public struct ActivityBreakdownItem: Equatable {
    public let activityType: String
    public let count: Int
    public let totalDistanceKM: Double
    public let totalDurationH: Double
    public let avgSpeedKMH: Double

    public init(activityType: String, count: Int, totalDistanceKM: Double, totalDurationH: Double, avgSpeedKMH: Double) {
        self.activityType = activityType
        self.count = count
        self.totalDistanceKM = totalDistanceKM
        self.totalDurationH = totalDurationH
        self.avgSpeedKMH = avgSpeedKMH
    }
}

public struct VisitTypeItem: Equatable {
    public let semanticType: String
    public let count: Int

    public init(semanticType: String, count: Int) {
        self.semanticType = semanticType
        self.count = count
    }
}

public struct PeriodBreakdownItem: Equatable {
    public let label: String
    public let year: Int
    public let month: Int?
    public let days: Int
    public let visits: Int
    public let activities: Int
    public let paths: Int
    public let distanceM: Double

    public init(label: String, year: Int, month: Int?, days: Int, visits: Int, activities: Int, paths: Int, distanceM: Double) {
        self.label = label
        self.year = year
        self.month = month
        self.days = days
        self.visits = visits
        self.activities = activities
        self.paths = paths
        self.distanceM = distanceM
    }
}

public struct DayAverages: Equatable {
    public let avgVisitsPerDay: Double
    public let avgActivitiesPerDay: Double
    public let avgPathsPerDay: Double
    public let avgDistancePerDayM: Double

    public init(avgVisitsPerDay: Double, avgActivitiesPerDay: Double, avgPathsPerDay: Double, avgDistancePerDayM: Double) {
        self.avgVisitsPerDay = avgVisitsPerDay
        self.avgActivitiesPerDay = avgActivitiesPerDay
        self.avgPathsPerDay = avgPathsPerDay
        self.avgDistancePerDayM = avgDistancePerDayM
    }
}
