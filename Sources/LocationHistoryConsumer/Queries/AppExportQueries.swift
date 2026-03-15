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
                totalPathDistanceM: day.paths.reduce(0) { $0 + ($1.distanceM ?? 0) }
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

    private static func sortedDays(in export: AppExport) -> [Day] {
        export.data.days.sorted { $0.date < $1.date }
    }
}
