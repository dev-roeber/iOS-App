import Foundation
import LocationHistoryConsumer

enum AppHistoryDateRangeQueryBridge {
    static func mergedFilter(
        base: AppExportQueryFilter?,
        rangeFilter: HistoryDateRangeFilter
    ) -> AppExportQueryFilter? {
        let fromDate = mergedLowerBound(base: base?.fromDate, range: rangeFilter.fromDateString)
        let toDate = mergedUpperBound(base: base?.toDate, range: rangeFilter.toDateString)

        if base == nil, fromDate == nil, toDate == nil {
            return nil
        }

        return AppExportQueryFilter(
            fromDate: fromDate,
            toDate: toDate,
            year: base?.year,
            month: base?.month,
            weekday: base?.weekday,
            limit: base?.limit,
            days: base?.days ?? [],
            requiredContent: base?.requiredContent ?? [],
            maxAccuracyM: base?.maxAccuracyM,
            activityTypes: base?.activityTypes ?? [],
            minGapMin: base?.minGapMin,
            spatialFilter: base?.spatialFilter
        )
    }

    private static func mergedLowerBound(base: String?, range: String?) -> String? {
        guard let range, !range.isEmpty else {
            return base
        }
        guard let base, !base.isEmpty else {
            return range
        }
        return max(base, range)
    }

    private static func mergedUpperBound(base: String?, range: String?) -> String? {
        guard let range, !range.isEmpty else {
            return base
        }
        guard let base, !base.isEmpty else {
            return range
        }
        return min(base, range)
    }
}
