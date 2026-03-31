import Foundation

public enum AppExportQueries {
    public static func overview(from export: AppExport) -> ExportOverview {
        overview(from: export, applying: nil)
    }

    public static func overview(from export: AppExport, applying filter: AppExportQueryFilter?) -> ExportOverview {
        let days = projectedDays(in: export, applying: filter)

        return ExportOverview(
            schemaVersion: export.schemaVersion.rawValue,
            exportedAt: export.meta.exportedAt,
            toolVersion: export.meta.toolVersion,
            inputFormat: export.meta.source.inputFormat,
            mode: export.meta.config.mode,
            splitMode: export.meta.config.splitMode,
            dayCount: days.count,
            totalVisitCount: days.reduce(0) { $0 + $1.visits.count },
            totalActivityCount: days.reduce(0) { $0 + $1.activities.count },
            totalPathCount: days.reduce(0) { $0 + $1.paths.count },
            statsActivityTypes: activityTypes(in: days)
        )
    }

    public static func daySummaries(from export: AppExport) -> [DaySummary] {
        daySummaries(from: export, applying: nil)
    }

    public static func daySummaries(from export: AppExport, applying filter: AppExportQueryFilter?) -> [DaySummary] {
        projectedDays(in: export, applying: filter).map(summary(for:))
    }

    public static func dayDetail(for date: String, in export: AppExport) -> DayDetailViewState? {
        dayDetail(for: date, in: export, applying: nil)
    }

    public static func dayDetail(
        for date: String,
        in export: AppExport,
        applying filter: AppExportQueryFilter?
    ) -> DayDetailViewState? {
        guard let day = findDay(on: date, in: export, applying: filter) else {
            return nil
        }

        let visits = day.visits.map {
            DayDetailViewState.VisitItem(
                startTime: $0.startTime,
                endTime: $0.endTime,
                semanticType: $0.semanticType,
                placeID: $0.placeID,
                lat: $0.lat,
                lon: $0.lon,
                accuracyM: $0.accuracyM,
                sourceType: $0.sourceType
            )
        }

        let activities = day.activities.map {
            DayDetailViewState.ActivityItem(
                startTime: $0.startTime,
                endTime: $0.endTime,
                activityType: $0.activityType,
                distanceM: $0.distanceM,
                splitFromMidnight: $0.splitFromMidnight,
                startLat: $0.startLat,
                startLon: $0.startLon,
                endLat: $0.endLat,
                endLon: $0.endLon,
                sourceType: $0.sourceType
            )
        }

        let paths = day.paths.map { path in
            DayDetailViewState.PathItem(
                startTime: path.startTime,
                endTime: path.endTime,
                activityType: path.activityType,
                distanceM: path.distanceM,
                pointCount: path.points.count,
                sourceType: path.sourceType,
                points: path.points.map {
                    DayDetailViewState.PathPointItem(
                        lat: $0.lat,
                        lon: $0.lon,
                        time: $0.time,
                        accuracyM: $0.accuracyM
                    )
                }
            )
        }

        return DayDetailViewState(
            date: day.date,
            visits: visits,
            activities: activities,
            paths: paths,
            totalPathPointCount: paths.reduce(0) { $0 + $1.pointCount },
            hasContent: !visits.isEmpty || !activities.isEmpty || !paths.isEmpty
        )
    }

    public static func findDay(on date: String, in export: AppExport) -> Day? {
        findDay(on: date, in: export, applying: nil)
    }

    public static func findDay(on date: String, in export: AppExport, applying filter: AppExportQueryFilter?) -> Day? {
        projectedDays(in: export, applying: filter).first { $0.date == date }
    }

    public static func days(in export: AppExport, from startDate: String? = nil, to endDate: String? = nil) -> [Day] {
        days(in: export, from: startDate, to: endDate, applying: nil)
    }

    public static func days(
        in export: AppExport,
        from startDate: String? = nil,
        to endDate: String? = nil,
        applying filter: AppExportQueryFilter?
    ) -> [Day] {
        projectedDays(in: export, applying: filter).filter { day in
            if let startDate, day.date < startDate {
                return false
            }
            if let endDate, day.date > endDate {
                return false
            }
            return true
        }
    }

    public static func insights(from export: AppExport) -> ExportInsights {
        insights(from: export, applying: nil)
    }

    public static func insights(from export: AppExport, applying filter: AppExportQueryFilter?) -> ExportInsights {
        let queryFilter = resolvedFilter(filter, export: export)
        let days = projectedDays(in: export, applying: queryFilter)
        let summaries = days.map(summary(for:))
        let dayCount = days.count

        let dateRange: InsightsDateRange? = days.isEmpty ? nil : InsightsDateRange(
            firstDate: days.first!.date,
            lastDate: days.last!.date
        )

        let totalDistanceM = summaries.reduce(0.0) { $0 + $1.totalPathDistanceM }
        let totalVisits = summaries.reduce(0) { $0 + $1.visitCount }
        let totalActivities = summaries.reduce(0) { $0 + $1.activityCount }
        let totalPaths = summaries.reduce(0) { $0 + $1.pathCount }

        return ExportInsights(
            dateRange: dateRange,
            totalDistanceM: totalDistanceM,
            activityBreakdown: activityBreakdown(in: days),
            visitTypeBreakdown: visitTypeBreakdown(in: days),
            periodBreakdown: periodBreakdown(in: days),
            averagesPerDay: DayAverages(
                avgVisitsPerDay: dayCount > 0 ? Double(totalVisits) / Double(dayCount) : 0,
                avgActivitiesPerDay: dayCount > 0 ? Double(totalActivities) / Double(dayCount) : 0,
                avgPathsPerDay: dayCount > 0 ? Double(totalPaths) / Double(dayCount) : 0,
                avgDistancePerDayM: dayCount > 0 ? totalDistanceM / Double(dayCount) : 0
            ),
            busiestDay: busiestDay(in: summaries),
            mostVisitsDay: mostVisitsDay(in: summaries),
            mostRoutesDay: mostRoutesDay(in: summaries),
            longestDistanceDay: longestDistanceDay(in: summaries),
            activeFilterDescriptions: filterDescriptions(from: queryFilter)
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let isoTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let isoTimestampFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private struct ActivityAggregate {
        var count = 0
        var totalDistanceKM = 0.0
        var totalDurationH = 0.0
    }

    private struct PeriodAggregate {
        let label: String
        let year: Int
        let month: Int?
        var days = 0
        var visits = 0
        var activities = 0
        var paths = 0
        var distanceM = 0.0
    }

    private static func resolvedFilter(_ filter: AppExportQueryFilter?, export: AppExport) -> AppExportQueryFilter {
        filter ?? AppExportQueryFilter(exportFilters: export.meta.filters)
    }

    private static func projectedDays(in export: AppExport, applying filter: AppExportQueryFilter?) -> [Day] {
        let queryFilter = resolvedFilter(filter, export: export)
        let sortedDays = export.data.days.sorted { $0.date < $1.date }
        let filteredDays = sortedDays.compactMap { projectedDay($0, applying: queryFilter) }

        if let limit = queryFilter.limit, limit >= 0 {
            return Array(filteredDays.prefix(limit))
        }

        return filteredDays
    }

    private static func projectedDay(_ day: Day, applying filter: AppExportQueryFilter) -> Day? {
        guard matchesDayMetadata(day.date, filter: filter) else {
            return nil
        }

        let filteredVisits = day.visits.filter { matchesVisit($0, filter: filter) }
        let filteredActivities = day.activities.filter { matchesActivity($0, filter: filter) }
        let filteredPaths = day.paths.compactMap { projectedPath($0, filter: filter) }

        let projectedDay = Day(
            date: day.date,
            visits: filteredVisits,
            activities: filteredActivities,
            paths: filteredPaths
        )

        guard matchesRequiredContent(projectedDay, filter: filter) else {
            return nil
        }

        if filter.hasContentConstraint &&
            projectedDay.visits.isEmpty &&
            projectedDay.activities.isEmpty &&
            projectedDay.paths.isEmpty {
            return nil
        }

        return projectedDay
    }

    private static func matchesDayMetadata(_ date: String, filter: AppExportQueryFilter) -> Bool {
        if let fromDate = filter.fromDate, date < fromDate {
            return false
        }
        if let toDate = filter.toDate, date > toDate {
            return false
        }
        if !filter.days.isEmpty, !filter.days.contains(date) {
            return false
        }
        if let year = filter.year, dateYear(date) != year {
            return false
        }
        if let month = filter.month, dateMonth(date) != month {
            return false
        }
        if let weekday = filter.weekday, weekdayForDate(date) != weekday {
            return false
        }
        return true
    }

    private static func matchesVisit(_ visit: Visit, filter: AppExportQueryFilter) -> Bool {
        if let maxAccuracyM = filter.maxAccuracyM,
           let accuracyM = visit.accuracyM,
           accuracyM > maxAccuracyM {
            return false
        }

        if let spatialFilter = filter.spatialFilter {
            guard let lat = visit.lat, let lon = visit.lon else {
                return false
            }
            return spatialFilter.contains(lat: lat, lon: lon)
        }

        return true
    }

    private static func matchesActivity(_ activity: Activity, filter: AppExportQueryFilter) -> Bool {
        let activityType = normalizedActivityType(activity.activityType)
        if !filter.activityTypes.isEmpty, !filter.activityTypes.contains(activityType) {
            return false
        }

        if let maxAccuracyM = filter.maxAccuracyM {
            if let startAccuracyM = activity.startAccuracyM, startAccuracyM > maxAccuracyM {
                return false
            }
            if let endAccuracyM = activity.endAccuracyM, endAccuracyM > maxAccuracyM {
                return false
            }
        }

        if let spatialFilter = filter.spatialFilter {
            let coordinates = activityCoordinates(activity)
            if coordinates.contains(where: { spatialFilter.contains($0) }) {
                return true
            }
            return false
        }

        return true
    }

    private static func projectedPath(_ path: Path, filter: AppExportQueryFilter) -> Path? {
        let activityType = normalizedActivityType(path.activityType)
        if !filter.activityTypes.isEmpty, !filter.activityTypes.contains(activityType) {
            return nil
        }

        let requiresPointProjection = filter.maxAccuracyM != nil || filter.spatialFilter != nil
        guard requiresPointProjection else {
            return path
        }

        let projectedPoints = path.points.filter { point in
            if let maxAccuracyM = filter.maxAccuracyM,
               let accuracyM = point.accuracyM,
               accuracyM > maxAccuracyM {
                return false
            }

            if let spatialFilter = filter.spatialFilter {
                return spatialFilter.contains(lat: point.lat, lon: point.lon)
            }

            return true
        }

        return ExportRouteSanitizer.sanitizedPath(
            Path(
                startTime: path.startTime,
                endTime: path.endTime,
                activityType: path.activityType,
                distanceM: path.distanceM,
                sourceType: path.sourceType,
                points: projectedPoints,
                flatCoordinates: path.flatCoordinates
            )
        )
    }

    private static func matchesRequiredContent(_ day: Day, filter: AppExportQueryFilter) -> Bool {
        for requirement in filter.requiredContent {
            switch requirement {
            case .visits where day.visits.isEmpty:
                return false
            case .activities where day.activities.isEmpty:
                return false
            case .paths where day.paths.isEmpty:
                return false
            default:
                continue
            }
        }
        return true
    }

    private static func summary(for day: Day) -> DaySummary {
        DaySummary(
            date: day.date,
            visitCount: day.visits.count,
            activityCount: day.activities.count,
            pathCount: day.paths.count,
            totalPathPointCount: day.paths.reduce(0) { $0 + $1.points.count },
            totalPathDistanceM: effectiveDistance(for: day),
            hasContent: !day.visits.isEmpty || !day.activities.isEmpty || !day.paths.isEmpty,
            exportablePathCount: ExportRouteSanitizer.exportablePathCount(in: day)
        )
    }

    private static func activityTypes(in days: [Day]) -> [String] {
        let types = days.reduce(into: Set<String>()) { partialResult, day in
            for activity in day.activities {
                partialResult.insert(normalizedActivityType(activity.activityType))
            }
            for path in day.paths {
                partialResult.insert(normalizedActivityType(path.activityType))
            }
        }

        return types.sorted()
    }

    private static func activityBreakdown(in days: [Day]) -> [ActivityBreakdownItem] {
        var aggregates: [String: ActivityAggregate] = [:]

        for day in days {
            for activity in day.activities {
                let type = normalizedActivityType(activity.activityType)
                var aggregate = aggregates[type, default: ActivityAggregate()]
                aggregate.count += 1
                aggregate.totalDistanceKM += effectiveDistance(for: activity) / 1000

                if let durationH = durationHours(start: activity.startTime, end: activity.endTime) {
                    aggregate.totalDurationH += durationH
                }

                aggregates[type] = aggregate
            }
        }

        return aggregates.map { key, value in
            ActivityBreakdownItem(
                activityType: key,
                count: value.count,
                totalDistanceKM: value.totalDistanceKM,
                totalDurationH: value.totalDurationH,
                avgSpeedKMH: value.totalDurationH > 0 ? value.totalDistanceKM / value.totalDurationH : 0
            )
        }
        .sorted {
            if $0.totalDistanceKM != $1.totalDistanceKM {
                return $0.totalDistanceKM > $1.totalDistanceKM
            }
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.activityType < $1.activityType
        }
    }

    private static func visitTypeBreakdown(in days: [Day]) -> [VisitTypeItem] {
        var counts: [String: Int] = [:]

        for day in days {
            for visit in day.visits {
                counts[visit.semanticType ?? "UNKNOWN", default: 0] += 1
            }
        }

        return counts.map { key, count in
            VisitTypeItem(semanticType: key, count: count)
        }
        .sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.semanticType < $1.semanticType
        }
    }

    private static func periodBreakdown(in days: [Day]) -> [PeriodBreakdownItem] {
        var aggregates: [String: PeriodAggregate] = [:]

        for day in days {
            let label = monthLabel(for: day.date)
            guard let year = dateYear(day.date) else {
                continue
            }

            var aggregate = aggregates[label] ?? PeriodAggregate(
                label: label,
                year: year,
                month: dateMonth(day.date)
            )
            aggregate.days += 1
            aggregate.visits += day.visits.count
            aggregate.activities += day.activities.count
            aggregate.paths += day.paths.count
            aggregate.distanceM += effectiveDistance(for: day)
            aggregates[label] = aggregate
        }

        return aggregates.values.map {
            PeriodBreakdownItem(
                label: $0.label,
                year: $0.year,
                month: $0.month,
                days: $0.days,
                visits: $0.visits,
                activities: $0.activities,
                paths: $0.paths,
                distanceM: $0.distanceM
            )
        }
        .sorted {
            if $0.year != $1.year {
                return $0.year < $1.year
            }
            return ($0.month ?? 0) < ($1.month ?? 0)
        }
    }

    private static func busiestDay(in summaries: [DaySummary]) -> DayHighlight? {
        guard let best = summaries.max(by: {
            ($0.visitCount + $0.activityCount + $0.pathCount) < ($1.visitCount + $1.activityCount + $1.pathCount)
        }) else {
            return nil
        }

        let total = best.visitCount + best.activityCount + best.pathCount
        guard total > 0 else {
            return nil
        }

        return DayHighlight(date: best.date, value: "\(total) events")
    }

    private static func mostVisitsDay(in summaries: [DaySummary]) -> DayHighlight? {
        guard let best = summaries.max(by: { $0.visitCount < $1.visitCount }),
              best.visitCount > 0 else {
            return nil
        }

        return DayHighlight(
            date: best.date,
            value: "\(best.visitCount) visit\(best.visitCount == 1 ? "" : "s")"
        )
    }

    private static func mostRoutesDay(in summaries: [DaySummary]) -> DayHighlight? {
        guard let best = summaries.max(by: { $0.pathCount < $1.pathCount }),
              best.pathCount > 0 else {
            return nil
        }

        return DayHighlight(
            date: best.date,
            value: "\(best.pathCount) route\(best.pathCount == 1 ? "" : "s")"
        )
    }

    private static func longestDistanceDay(in summaries: [DaySummary]) -> DayHighlight? {
        guard let best = summaries.max(by: { $0.totalPathDistanceM < $1.totalPathDistanceM }),
              best.totalPathDistanceM > 0 else {
            return nil
        }

        return DayHighlight(
            date: best.date,
            value: String(format: "%.1f km", best.totalPathDistanceM / 1000)
        )
    }

    private static func filterDescriptions(from filter: AppExportQueryFilter) -> [String] {
        var descriptions: [String] = []
        if let value = filter.fromDate { descriptions.append("From: \(value)") }
        if let value = filter.toDate { descriptions.append("To: \(value)") }
        if let value = filter.year { descriptions.append("Year: \(value)") }
        if let value = filter.month { descriptions.append("Month: \(value)") }
        if let value = filter.weekday { descriptions.append("Weekday: \(value)") }
        if let value = filter.limit { descriptions.append("Limit: \(value) days") }
        if !filter.days.isEmpty { descriptions.append("Days: \(filter.days.sorted().joined(separator: ", "))") }
        if !filter.requiredContent.isEmpty {
            descriptions.append("Has: \(filter.requiredContent.map(\.rawValue).sorted().joined(separator: ", "))")
        }
        if let value = filter.maxAccuracyM { descriptions.append("Max accuracy: \(Int(value))m") }
        if !filter.activityTypes.isEmpty {
            descriptions.append("Activity types: \(filter.activityTypes.sorted().map { $0.capitalized }.joined(separator: ", "))")
        }
        if let value = filter.minGapMin { descriptions.append("Min gap: \(value) min (upstream)") }
        if let spatialFilter = filter.spatialFilter {
            switch spatialFilter {
            case .bounds:
                descriptions.append("Area: Bounding box")
            case .polygon:
                descriptions.append("Area: Polygon")
            case let .all(filters):
                for filter in filters {
                    switch filter {
                    case .bounds:
                        descriptions.append("Area: Bounding box")
                    case .polygon:
                        descriptions.append("Area: Polygon")
                    case .all:
                        descriptions.append("Area: Combined filters")
                    }
                }
            }
        }
        return descriptions
    }

    private static func normalizedActivityType(_ value: String?) -> String {
        value ?? "UNKNOWN"
    }

    private static func activityCoordinates(_ activity: Activity) -> [ExportCoordinate] {
        if let flatCoordinates = activity.flatCoordinates, flatCoordinates.count >= 2 {
            return stride(from: 0, to: flatCoordinates.count - 1, by: 2).map {
                ExportCoordinate(lat: flatCoordinates[$0], lon: flatCoordinates[$0 + 1])
            }
        }

        var coordinates: [ExportCoordinate] = []
        if let startLat = activity.startLat, let startLon = activity.startLon {
            coordinates.append(ExportCoordinate(lat: startLat, lon: startLon))
        }
        if let endLat = activity.endLat, let endLon = activity.endLon {
            coordinates.append(ExportCoordinate(lat: endLat, lon: endLon))
        }
        return coordinates
    }

    private static func effectiveDistance(for day: Day) -> Double {
        let pathDistance = day.paths.reduce(0.0) { partialResult, path in
            partialResult + effectiveDistance(for: path)
        }
        guard pathDistance <= 0 else {
            return pathDistance
        }

        return day.activities.reduce(0.0) { partialResult, activity in
            partialResult + effectiveDistance(for: activity)
        }
    }

    private static func effectiveDistance(for path: Path) -> Double {
        if let distanceM = path.distanceM, distanceM > 0 {
            return distanceM
        }

        let pointCoordinates = path.points.map { ExportCoordinate(lat: $0.lat, lon: $0.lon) }
        if pointCoordinates.count >= 2 {
            return polylineDistance(for: pointCoordinates)
        }

        guard let flatCoordinates = path.flatCoordinates, flatCoordinates.count >= 4 else {
            return 0
        }
        return polylineDistance(
            for: stride(from: 0, to: flatCoordinates.count - 1, by: 2).map {
                ExportCoordinate(lat: flatCoordinates[$0], lon: flatCoordinates[$0 + 1])
            }
        )
    }

    private static func effectiveDistance(for activity: Activity) -> Double {
        if let distanceM = activity.distanceM, distanceM > 0 {
            return distanceM
        }

        guard let flatCoordinates = activity.flatCoordinates, flatCoordinates.count >= 4 else {
            return 0
        }
        return polylineDistance(
            for: stride(from: 0, to: flatCoordinates.count - 1, by: 2).map {
                ExportCoordinate(lat: flatCoordinates[$0], lon: flatCoordinates[$0 + 1])
            }
        )
    }

    private static func polylineDistance(for coordinates: [ExportCoordinate]) -> Double {
        guard coordinates.count >= 2 else {
            return 0
        }

        return zip(coordinates, coordinates.dropFirst()).reduce(0.0) { partialResult, pair in
            partialResult + haversineDistance(from: pair.0, to: pair.1)
        }
    }

    private static func haversineDistance(from start: ExportCoordinate, to end: ExportCoordinate) -> Double {
        let earthRadiusM = 6_371_000.0
        let startLat = start.lat * .pi / 180
        let endLat = end.lat * .pi / 180
        let deltaLat = (end.lat - start.lat) * .pi / 180
        let deltaLon = (end.lon - start.lon) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(startLat) * cos(endLat) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }

    private static func durationHours(start: String?, end: String?) -> Double? {
        guard let startDate = parseTimestamp(start),
              let endDate = parseTimestamp(end),
              endDate >= startDate else {
            return nil
        }

        return endDate.timeIntervalSince(startDate) / 3600
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        return isoTimestampFormatter.date(from: value) ?? isoTimestampFractionalFormatter.date(from: value)
    }

    private static func weekdayForDate(_ date: String) -> Int? {
        guard let parsedDate = dayFormatter.date(from: date) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC") ?? .current
        return calendar.component(.weekday, from: parsedDate)
    }

    private static func dateYear(_ date: String) -> Int? {
        Int(date.prefix(4))
    }

    private static func dateMonth(_ date: String) -> Int? {
        guard date.count >= 7 else {
            return nil
        }
        let start = date.index(date.startIndex, offsetBy: 5)
        let end = date.index(start, offsetBy: 2)
        return Int(date[start..<end])
    }

    private static func monthLabel(for date: String) -> String {
        guard date.count >= 7 else {
            return date
        }
        return String(date.prefix(7))
    }
}
