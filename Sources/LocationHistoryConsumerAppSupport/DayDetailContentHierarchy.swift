import Foundation
import LocationHistoryConsumer

struct DayDetailContentHierarchy: Equatable {
    enum Section: String, Equatable {
        case importedMap
        case metricGrid
        case actions
        case segmentControl
        case overview
        case timeline
        case visits
        case activities
        case routes
        case localRecording
    }

    struct TimeRange: Equatable {
        let earliest: Date
        let latest: Date
    }

    let sections: [Section]
    let timeRange: TimeRange?
    let totalDistanceM: Double

    init(detail: DayDetailViewState, hasLiveLocationTools: Bool) {
        self.timeRange = Self.makeTimeRange(detail: detail)
        self.totalDistanceM = detail.paths.reduce(0.0) { $0 + ($1.distanceM ?? 0) }

        var sections: [Section] = [.importedMap, .metricGrid, .actions, .segmentControl, .overview]
        if timeRange != nil {
            sections.append(.timeline)
        }
        if !detail.visits.isEmpty {
            sections.append(.visits)
        }
        if !detail.activities.isEmpty {
            sections.append(.activities)
        }
        if !detail.paths.isEmpty {
            sections.append(.routes)
        }
        if hasLiveLocationTools {
            sections.append(.localRecording)
        }
        self.sections = sections
    }

    static func makeTimeRange(detail: DayDetailViewState) -> TimeRange? {
        let allStarts = detail.visits.compactMap(\.startTime) + detail.activities.compactMap(\.startTime) + detail.paths.compactMap(\.startTime)
        let allEnds = detail.visits.compactMap(\.endTime) + detail.activities.compactMap(\.endTime) + detail.paths.compactMap(\.endTime)
        let earliest = allStarts.compactMap(parseDate).min()
        let latest = allEnds.compactMap(parseDate).max()

        guard let earliest, let latest, latest >= earliest else {
            return nil
        }
        return TimeRange(earliest: earliest, latest: latest)
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = fractionalParser.date(from: value) {
            return date
        }
        return standardParser.date(from: value)
    }

    private static let standardParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
