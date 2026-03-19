import Foundation
import LocationHistoryConsumer

enum ExportReadiness: Equatable {
    case nothingSelected
    case noRoutesSelected(selectedSourceCount: Int)
    case ready(
        selectedSourceCount: Int,
        exportableSourceCount: Int,
        routeCount: Int,
        selectedDayCount: Int,
        selectedRecordedTrackCount: Int
    )
}

enum ExportPresentation {
    static func readiness(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack]
    ) -> ExportReadiness {
        let snapshot = ExportSelectionContent.snapshot(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )

        guard snapshot.selectedSourceCount > 0 else {
            return .nothingSelected
        }

        guard snapshot.routeCount > 0 else {
            return .noRoutesSelected(selectedSourceCount: snapshot.selectedSourceCount)
        }

        return .ready(
            selectedSourceCount: snapshot.selectedSourceCount,
            exportableSourceCount: snapshot.exportableSourceCount,
            routeCount: snapshot.routeCount,
            selectedDayCount: snapshot.selectedDayCount,
            selectedRecordedTrackCount: snapshot.selectedRecordedTrackCount
        )
    }

    static func buttonTitle(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat
    ) -> String {
        switch readiness(selection: selection, summaries: summaries, recordedTracks: recordedTracks) {
        case .nothingSelected:
            return "Select history or tracks to export"
        case let .noRoutesSelected(selectedSourceCount):
            return selectedSourceCount == 1
                ? "Selected item has no routes"
                : "Selected items have no routes"
        case let .ready(selectedSourceCount, _, _, _, _):
            return "Export \(selectedSourceCount) \(selectedSourceCount == 1 ? "item" : "items") as \(format.rawValue)"
        }
    }

    static func helperMessage(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat
    ) -> String {
        switch readiness(selection: selection, summaries: summaries, recordedTracks: recordedTracks) {
        case .nothingSelected:
            return "Choose at least one imported day or saved track with routes to prepare a \(format.rawValue) file."
        case let .noRoutesSelected(selectedSourceCount):
            return selectedSourceCount == 1
                ? "The selected item contains no route with usable GPS points."
                : "None of the selected items contain routes with usable GPS points."
        case let .ready(selectedSourceCount, exportableSourceCount, routeCount, _, _):
            if exportableSourceCount < selectedSourceCount {
                return "\(exportableSourceCount) of \(selectedSourceCount) selected items contribute \(routeCount) route\(routeCount == 1 ? "" : "s"). Items without routes stay out of the \(format.rawValue) content."
            }
            return "\(routeCount) route\(routeCount == 1 ? "" : "s") will be written to the \(format.rawValue) file."
        }
    }

    static func suggestedFilename(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat
    ) -> String {
        let sortedDates = ExportSelectionContent.filenameDates(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        switch sortedDates.count {
        case 0:
            return "lh2gpx-export.\(format.fileExtension)"
        case 1:
            return "lh2gpx-\(sortedDates[0]).\(format.fileExtension)"
        default:
            guard let first = sortedDates.first, let last = sortedDates.last else {
                return "lh2gpx-export.\(format.fileExtension)"
            }
            return "lh2gpx-\(first)_to_\(last).\(format.fileExtension)"
        }
    }

    static func filenameMessage(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat
    ) -> String {
        let filename = suggestedFilename(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks,
            format: format
        )
        return "Suggested filename: \(filename) (\(format.fileExtension.uppercased()))."
    }
}
