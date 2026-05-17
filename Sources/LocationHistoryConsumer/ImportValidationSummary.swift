import Foundation

/// Train O, Phase 1 — Foundation-only summary of an `AppExport` produced
/// by the import pipeline. Carries counts, a date range and a small set
/// of structural warnings so the UI can surface "what was loaded" to the
/// user without exposing any coordinates.
///
/// **Privacy:** the summary contains no latitude/longitude, no street
/// addresses and no place IDs. Date strings are the existing
/// `yyyy-MM-dd` keys that already live in `Day.date` and are required
/// for time-range filtering throughout the app.
public struct ImportValidationSummary: Equatable, Sendable {

    public let dayCount: Int
    public let visitCount: Int
    public let activityCount: Int
    public let pathCount: Int
    /// Sum of decoded path-point counts across all days. A path's points
    /// are counted via `points.count` when available; otherwise via
    /// `flatCoordinates.count / 2` (Google Timeline post-2026-05-08
    /// flat-shape). Both fields are guarded against odd lengths.
    public let totalPathPointCount: Int
    /// Earliest `Day.date` string in the export, sorted lexicographically
    /// (the existing `yyyy-MM-dd` keys are sort-stable).
    public let firstDate: String?
    public let lastDate: String?
    public let warnings: [Warning]

    public enum Warning: String, Equatable, Sendable, CaseIterable {
        /// No `Day` rows at all.
        case emptyImport
        /// Days exist but contain zero path points and zero visit
        /// coordinates. The import is structurally valid but carries no
        /// usable GPS data.
        case noGPSPoints
        /// Exactly one day. Not a hard error — many real exports cover
        /// a single day — but worth surfacing so users don't think the
        /// rest of their data got dropped.
        case singleDayOnly
    }

    public init(
        dayCount: Int,
        visitCount: Int,
        activityCount: Int,
        pathCount: Int,
        totalPathPointCount: Int,
        firstDate: String?,
        lastDate: String?,
        warnings: [Warning]
    ) {
        self.dayCount = dayCount
        self.visitCount = visitCount
        self.activityCount = activityCount
        self.pathCount = pathCount
        self.totalPathPointCount = totalPathPointCount
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.warnings = warnings
    }

    public static let empty = ImportValidationSummary(
        dayCount: 0, visitCount: 0, activityCount: 0,
        pathCount: 0, totalPathPointCount: 0,
        firstDate: nil, lastDate: nil,
        warnings: [.emptyImport]
    )

    /// Builds a summary from an `AppExport`. Pure, no I/O, no mutation.
    public static func summarize(_ export: AppExport) -> ImportValidationSummary {
        let days = export.data.days
        guard !days.isEmpty else { return .empty }

        var visitCount = 0
        var activityCount = 0
        var pathCount = 0
        var totalPoints = 0
        var hasVisitCoordinate = false

        for day in days {
            visitCount += day.visits.count
            activityCount += day.activities.count
            pathCount += day.paths.count
            for visit in day.visits {
                if visit.lat != nil && visit.lon != nil {
                    hasVisitCoordinate = true
                }
            }
            for path in day.paths {
                if !path.points.isEmpty {
                    totalPoints += path.points.count
                } else if let flat = path.flatCoordinates, flat.count >= 2, flat.count.isMultiple(of: 2) {
                    totalPoints += flat.count / 2
                }
            }
        }

        let dates = days.map(\.date).sorted()
        var warnings: [Warning] = []
        if totalPoints == 0 && !hasVisitCoordinate {
            warnings.append(.noGPSPoints)
        }
        if dates.count == 1 {
            warnings.append(.singleDayOnly)
        }

        return ImportValidationSummary(
            dayCount: dates.count,
            visitCount: visitCount,
            activityCount: activityCount,
            pathCount: pathCount,
            totalPathPointCount: totalPoints,
            firstDate: dates.first,
            lastDate: dates.last,
            warnings: warnings
        )
    }
}
