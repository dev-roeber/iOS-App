import Foundation

public enum AppExportQueries {
    public static func overview(from export: AppExport) -> ExportOverview {
        let sortedDays = sortedDays(in: export)

        return ExportOverview(
            schemaVersion: export.schemaVersion.rawValue,
            exportedAt: export.meta.exportedAt,
            toolVersion: export.meta.toolVersion,
            inputFormat: export.meta.source.inputFormat,
            mode: export.meta.config.mode,
            splitMode: export.meta.config.splitMode,
            dayCount: sortedDays.count,
            totalVisitCount: sortedDays.reduce(0) { $0 + $1.visits.count },
            totalActivityCount: sortedDays.reduce(0) { $0 + $1.activities.count },
            totalPathCount: sortedDays.reduce(0) { $0 + $1.paths.count },
            statsActivityTypes: export.stats?.activities.map { Array($0.keys).sorted() } ?? []
        )
    }

    public static func daySummaries(from export: AppExport) -> [DaySummary] {
        sortedDays(in: export).map { day in
            DaySummary(
                date: day.date,
                visitCount: day.visits.count,
                activityCount: day.activities.count,
                pathCount: day.paths.count,
                totalPathPointCount: day.paths.reduce(0) { $0 + $1.points.count },
                totalPathDistanceM: day.paths.reduce(0) { $0 + ($1.distanceM ?? 0) },
                hasContent: !day.visits.isEmpty || !day.activities.isEmpty || !day.paths.isEmpty,
                exportablePathCount: day.paths.filter { !$0.points.isEmpty }.count
            )
        }
    }

    public static func dayDetail(for date: String, in export: AppExport) -> DayDetailViewState? {
        guard let day = findDay(on: date, in: export) else {
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
        sortedDays(in: export).first { $0.date == date }
    }

    public static func days(in export: AppExport, from startDate: String? = nil, to endDate: String? = nil) -> [Day] {
        sortedDays(in: export).filter { day in
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
        let days = sortedDays(in: export)
        let dayCount = days.count

        let dateRange: InsightsDateRange? = days.isEmpty ? nil : InsightsDateRange(
            firstDate: days.first!.date,
            lastDate: days.last!.date
        )

        let totalDistanceM = days.reduce(0.0) { total, day in
            total + day.paths.reduce(0.0) { $0 + ($1.distanceM ?? 0) }
        }

        let activityBreakdown: [ActivityBreakdownItem]
        if let statsActivities = export.stats?.activities, !statsActivities.isEmpty {
            activityBreakdown = statsActivities.map { key, value in
                ActivityBreakdownItem(
                    activityType: key,
                    count: value.count,
                    totalDistanceKM: value.totalDistanceKM,
                    totalDurationH: value.totalDurationH,
                    avgSpeedKMH: value.avgSpeedKMH
                )
            }.sorted { $0.totalDistanceKM > $1.totalDistanceKM }
        } else {
            var typeCounts: [String: Int] = [:]
            var typeDistances: [String: Double] = [:]
            for day in days {
                for activity in day.activities {
                    let type = activity.activityType ?? "UNKNOWN"
                    typeCounts[type, default: 0] += 1
                    typeDistances[type, default: 0] += (activity.distanceM ?? 0) / 1000
                }
            }
            activityBreakdown = typeCounts.map { key, count in
                ActivityBreakdownItem(
                    activityType: key,
                    count: count,
                    totalDistanceKM: typeDistances[key] ?? 0,
                    totalDurationH: 0,
                    avgSpeedKMH: 0
                )
            }.sorted { $0.totalDistanceKM > $1.totalDistanceKM }
        }

        var visitTypeCounts: [String: Int] = [:]
        for day in days {
            for visit in day.visits {
                let type = visit.semanticType ?? "UNKNOWN"
                visitTypeCounts[type, default: 0] += 1
            }
        }
        let visitTypeBreakdown = visitTypeCounts.map { key, count in
            VisitTypeItem(semanticType: key, count: count)
        }.sorted { $0.count > $1.count }

        let periodBreakdown = (export.stats?.periods ?? []).map { period in
            PeriodBreakdownItem(
                label: period.label,
                year: period.year,
                month: period.month,
                days: period.days,
                visits: period.visits,
                activities: period.activities,
                paths: period.paths,
                distanceM: period.distanceM
            )
        }

        let totalVisits = days.reduce(0) { $0 + $1.visits.count }
        let totalActivities = days.reduce(0) { $0 + $1.activities.count }
        let totalPaths = days.reduce(0) { $0 + $1.paths.count }

        // Derive summaries from the already-sorted `days` to avoid a second sort.
        let summaries = days.map { day in
            DaySummary(
                date: day.date,
                visitCount: day.visits.count,
                activityCount: day.activities.count,
                pathCount: day.paths.count,
                totalPathPointCount: day.paths.reduce(0) { $0 + $1.points.count },
                totalPathDistanceM: day.paths.reduce(0) { $0 + ($1.distanceM ?? 0) },
                hasContent: !day.visits.isEmpty || !day.activities.isEmpty || !day.paths.isEmpty,
                exportablePathCount: day.paths.filter { !$0.points.isEmpty }.count
            )
        }

        let busiestDay: DayHighlight? = {
            guard let best = summaries.max(by: {
                ($0.visitCount + $0.activityCount + $0.pathCount) < ($1.visitCount + $1.activityCount + $1.pathCount)
            }), (best.visitCount + best.activityCount + best.pathCount) > 0 else { return nil }
            let total = best.visitCount + best.activityCount + best.pathCount
            return DayHighlight(date: best.date, value: "\(total) events")
        }()

        let mostVisitsDay: DayHighlight? = {
            guard let best = summaries.max(by: { $0.visitCount < $1.visitCount }),
                  best.visitCount > 0 else { return nil }
            return DayHighlight(
                date: best.date,
                value: "\(best.visitCount) visit\(best.visitCount == 1 ? "" : "s")"
            )
        }()

        let mostRoutesDay: DayHighlight? = {
            guard let best = summaries.max(by: { $0.pathCount < $1.pathCount }),
                  best.pathCount > 0 else { return nil }
            return DayHighlight(
                date: best.date,
                value: "\(best.pathCount) route\(best.pathCount == 1 ? "" : "s")"
            )
        }()

        let longestDistanceDay: DayHighlight? = {
            guard let best = summaries.max(by: { $0.totalPathDistanceM < $1.totalPathDistanceM }),
                  best.totalPathDistanceM > 0 else { return nil }
            let km = best.totalPathDistanceM / 1000
            return DayHighlight(date: best.date, value: String(format: "%.1f km", km))
        }()

        let activeFilterDescriptions = Self.filterDescriptions(from: export.meta.filters)

        return ExportInsights(
            dateRange: dateRange,
            totalDistanceM: totalDistanceM,
            activityBreakdown: activityBreakdown,
            visitTypeBreakdown: visitTypeBreakdown,
            periodBreakdown: periodBreakdown,
            averagesPerDay: DayAverages(
                avgVisitsPerDay: dayCount > 0 ? Double(totalVisits) / Double(dayCount) : 0,
                avgActivitiesPerDay: dayCount > 0 ? Double(totalActivities) / Double(dayCount) : 0,
                avgPathsPerDay: dayCount > 0 ? Double(totalPaths) / Double(dayCount) : 0,
                avgDistancePerDayM: dayCount > 0 ? totalDistanceM / Double(dayCount) : 0
            ),
            busiestDay: busiestDay,
            mostVisitsDay: mostVisitsDay,
            mostRoutesDay: mostRoutesDay,
            longestDistanceDay: longestDistanceDay,
            activeFilterDescriptions: activeFilterDescriptions
        )
    }

    private static func filterDescriptions(from filters: ExportFilters) -> [String] {
        var descriptions: [String] = []
        if let v = filters.fromDate { descriptions.append("From: \(v)") }
        if let v = filters.toDate { descriptions.append("To: \(v)") }
        if let v = filters.year { descriptions.append("Year: \(v)") }
        if let v = filters.month { descriptions.append("Month: \(v)") }
        if let v = filters.weekday { descriptions.append("Weekday: \(v)") }
        if let v = filters.limit { descriptions.append("Limit: \(v) days") }
        if let v = filters.days, !v.isEmpty { descriptions.append("Days: \(v.joined(separator: ", "))") }
        if let v = filters.has, !v.isEmpty { descriptions.append("Has: \(v.joined(separator: ", "))") }
        if let v = filters.maxAccuracyM { descriptions.append("Max accuracy: \(Int(v))m") }
        if let v = filters.activityTypes, !v.isEmpty { descriptions.append("Activity types: \(v.map { $0.capitalized }.joined(separator: ", "))") }
        if let v = filters.minGapMin { descriptions.append("Min gap: \(v) min") }
        return descriptions
    }

    private static func sortedDays(in export: AppExport) -> [Day] {
        export.data.days.sorted { $0.date < $1.date }
    }
}
