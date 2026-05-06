import Foundation
import LocationHistoryConsumer

struct ExportSelectionSnapshot: Equatable {
    let selectedDayCount: Int
    let selectedRecordedTrackCount: Int
    let exportableSourceCount: Int
    let routeCount: Int
    let waypointCount: Int

    var selectedSourceCount: Int {
        selectedDayCount + selectedRecordedTrackCount
    }

    var contentCount: Int {
        routeCount + waypointCount
    }
}

enum ExportSelectionContent {
    private static let isoTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func snapshot(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode
    ) -> ExportSelectionSnapshot {
        let selectedImportedDays = selectedImportedDays(
            in: importedExport,
            selection: selection,
            queryFilter: queryFilter
        )
        let selectedRecordedTracks = recordedTracks
            .filter { selection.isSelected(recordedTrackID: $0.id) }
            .sorted { $0.startedAt < $1.startedAt }
        let routeDays = mode.includesTracks
            ? selectedImportedDays.compactMap(ExportRouteSanitizer.sanitizedDay)
            : []
        let waypointCounts = mode.includesWaypoints
            ? selectedImportedDays.map(ExportWaypointExtractor.count(in:))
            : Array(repeating: 0, count: selectedImportedDays.count)
        let exportableImportedDayCount = zip(selectedImportedDays, waypointCounts).reduce(0) { partial, pair in
            let dayHasRoutes = mode.includesTracks && ExportRouteSanitizer.sanitizedDay(pair.0) != nil
            let dayHasWaypoints = mode.includesWaypoints && pair.1 > 0
            return partial + ((dayHasRoutes || dayHasWaypoints) ? 1 : 0)
        }
        let exportableRecordedTrackCount = mode.includesTracks
            ? selectedRecordedTracks.filter(isExportableRecordedTrack).count
            : 0

        return ExportSelectionSnapshot(
            selectedDayCount: selectedImportedDays.count,
            selectedRecordedTrackCount: selectedRecordedTracks.count,
            exportableSourceCount: exportableImportedDayCount + exportableRecordedTrackCount,
            routeCount: routeDays.reduce(0) { $0 + $1.paths.count } + exportableRecordedTrackCount,
            waypointCount: waypointCounts.reduce(0, +)
        )
    }

    static func exportDays(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil,
        mutations: ImportedPathMutationSet = .empty
    ) -> [Day] {
        let importedDays = selectedImportedDays(
            in: importedExport,
            selection: selection,
            queryFilter: queryFilter
        )
        // User-deleted paths in the day-detail view used to be display-only —
        // the export silently re-included them. Apply the mutation overlay
        // here so GPX/KML/KMZ/GeoJSON/CSV all honour the deletions exactly
        // like the day detail.
        let mutatedImportedDays = importedDays.map { day in
            applyMutations(day, mutations: mutations)
        }
        let liveTrackDays = selectedRecordedTrackDays(
            recordedTracks: recordedTracks,
            selection: selection
        )

        return (mutatedImportedDays + liveTrackDays).sorted { lhs, rhs in
            lhs.date < rhs.date
        }
    }

    /// Removes path indices listed in `mutations` for this day's date. Indices
    /// out of range and deletions for other days are silently ignored — keeps
    /// the overlay model resilient to import-source switches.
    private static func applyMutations(_ day: Day, mutations: ImportedPathMutationSet) -> Day {
        let deletedIndices = Set(
            mutations.deletions
                .filter { $0.dayKey == day.date }
                .map(\.pathIndex)
        )
        guard !deletedIndices.isEmpty else { return day }
        let kept = day.paths.enumerated()
            .filter { !deletedIndices.contains($0.offset) }
            .map(\.element)
        return Day(date: day.date, visits: day.visits, activities: day.activities, paths: kept)
    }

    static func filenameDates(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> [String] {
        let importedDates = summaries.filter { selection.isSelected($0.date) }.map(\.date)
        let recordedDates = recordedTracks
            .filter { selection.isSelected(recordedTrackID: $0.id) }
            .map(\.dayKey)
        return Array(Set(importedDates + recordedDates)).sorted()
    }

    private static func selectedImportedDays(
        in export: AppExport?,
        selection: ExportSelectionState,
        queryFilter: AppExportQueryFilter?
    ) -> [Day] {
        guard let export else {
            return []
        }

        return AppExportQueries.days(in: export, applying: queryFilter)
            .filter { selection.isSelected($0.date) }
            .map { applyRouteSelection(to: $0, selection: selection) }
    }

    private static func applyRouteSelection(to day: Day, selection: ExportSelectionState) -> Day {
        let effectiveIndices = selection.effectiveRouteIndices(day: day.date, allCount: day.paths.count)
        guard effectiveIndices.count != day.paths.count else {
            return day
        }

        let selectedPaths = day.paths.enumerated().compactMap { index, path in
            effectiveIndices.contains(index) ? path : nil
        }
        return Day(
            date: day.date,
            visits: day.visits,
            activities: day.activities,
            paths: selectedPaths
        )
    }

    private static func selectedRecordedTrackDays(
        recordedTracks: [RecordedTrack],
        selection: ExportSelectionState
    ) -> [Day] {
        recordedTracks
            .filter { selection.isSelected(recordedTrackID: $0.id) }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap(exportDay(for:))
    }

    private static func exportDay(for track: RecordedTrack) -> Day? {
        let pathPoints = track.points.map { point in
            PathPoint(
                lat: point.latitude,
                lon: point.longitude,
                time: isoTimestampFormatter.string(from: point.timestamp),
                accuracyM: point.horizontalAccuracyM
            )
        }

        let rawPath = Path(
            startTime: isoTimestampFormatter.string(from: track.startedAt),
            endTime: isoTimestampFormatter.string(from: track.endedAt),
            activityType: "LIVE TRACK",
            distanceM: track.distanceM,
            sourceType: "recorded_live_track",
            points: pathPoints,
            flatCoordinates: nil
        )

        guard let path = ExportRouteSanitizer.sanitizedPath(rawPath) else {
            return nil
        }

        return Day(
            date: track.dayKey,
            visits: [],
            activities: [],
            paths: [path]
        )
    }

    private static func isExportableRecordedTrack(_ track: RecordedTrack) -> Bool {
        exportDay(for: track) != nil
    }
}
