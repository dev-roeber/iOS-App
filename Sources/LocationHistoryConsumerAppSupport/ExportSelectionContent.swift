import Foundation
import LocationHistoryConsumer

struct ExportSelectionSnapshot: Equatable {
    let selectedDaySummaries: [DaySummary]
    let selectedRecordedTracks: [RecordedTrack]
    let exportableDaySummaries: [DaySummary]
    let exportableRecordedTracks: [RecordedTrack]

    var selectedSourceCount: Int {
        selectedDaySummaries.count + selectedRecordedTracks.count
    }

    var exportableSourceCount: Int {
        exportableDaySummaries.count + exportableRecordedTracks.count
    }

    var selectedDayCount: Int {
        selectedDaySummaries.count
    }

    var selectedRecordedTrackCount: Int {
        selectedRecordedTracks.count
    }

    var routeCount: Int {
        exportableDaySummaries.reduce(0) { $0 + $1.exportablePathCount } + exportableRecordedTracks.count
    }
}

enum ExportSelectionContent {
    private static let isoTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func snapshot(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> ExportSelectionSnapshot {
        let selectedDaySummaries = summaries.filter { selection.isSelected($0.date) }
        let selectedRecordedTracks = recordedTracks
            .filter { selection.isSelected(recordedTrackID: $0.id) }
            .sorted { $0.startedAt < $1.startedAt }

        return ExportSelectionSnapshot(
            selectedDaySummaries: selectedDaySummaries,
            selectedRecordedTracks: selectedRecordedTracks,
            exportableDaySummaries: selectedDaySummaries.filter { $0.exportablePathCount > 0 },
            exportableRecordedTracks: selectedRecordedTracks.filter(isExportableRecordedTrack)
        )
    }

    static func exportDays(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil
    ) -> [Day] {
        let importedDays = selectedImportedDays(
            in: importedExport,
            selection: selection,
            queryFilter: queryFilter
        )
        let liveTrackDays = selectedRecordedTrackDays(
            recordedTracks: recordedTracks,
            selection: selection
        )

        return (importedDays + liveTrackDays).sorted { lhs, rhs in
            lhs.date < rhs.date
        }
    }

    static func filenameDates(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> [String] {
        let snapshot = snapshot(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        let importedDates = snapshot.selectedDaySummaries.map(\.date)
        let recordedDates = snapshot.selectedRecordedTracks.map(\.dayKey)
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
            .compactMap(ExportRouteSanitizer.sanitizedDay)
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
