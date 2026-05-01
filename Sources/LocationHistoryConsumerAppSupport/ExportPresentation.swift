import Foundation
import LocationHistoryConsumer

enum ExportReadiness: Equatable {
    case nothingSelected
    case noExportableContent(selectedSourceCount: Int)
    case ready(
        selectedSourceCount: Int,
        exportableSourceCount: Int,
        routeCount: Int,
        waypointCount: Int,
        selectedDayCount: Int,
        selectedRecordedTrackCount: Int
    )
}

enum ExportPresentation {
    static func readiness(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack]
        ,
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode
    ) -> ExportReadiness {
        let snapshot = ExportSelectionContent.snapshot(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mode: mode
        )

        guard snapshot.selectedSourceCount > 0 else {
            return .nothingSelected
        }

        guard snapshot.contentCount > 0 else {
            return .noExportableContent(selectedSourceCount: snapshot.selectedSourceCount)
        }

        return .ready(
            selectedSourceCount: snapshot.selectedSourceCount,
            exportableSourceCount: snapshot.exportableSourceCount,
            routeCount: snapshot.routeCount,
            waypointCount: snapshot.waypointCount,
            selectedDayCount: snapshot.selectedDayCount,
            selectedRecordedTrackCount: snapshot.selectedRecordedTrackCount
        )
    }

    static func buttonTitle(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        format: ExportFormat,
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode,
        language: AppLanguagePreference = .english
    ) -> String {
        switch readiness(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mode: mode
        ) {
        case .nothingSelected:
            return language.isGerman ? "Historie oder Tracks für den Export auswählen" : "Select history or tracks to export"
        case let .noExportableContent(selectedSourceCount):
            switch mode {
            case .tracks:
                return language.isGerman
                    ? (selectedSourceCount == 1 ? "Ausgewählter Eintrag hat keine Routen" : "Ausgewählte Einträge haben keine Routen")
                    : (selectedSourceCount == 1 ? "Selected item has no routes" : "Selected items have no routes")
            case .waypoints:
                return language.isGerman
                    ? (selectedSourceCount == 1 ? "Ausgewählter Eintrag hat keine Wegpunkte" : "Ausgewählte Einträge haben keine Wegpunkte")
                    : (selectedSourceCount == 1 ? "Selected item has no waypoints" : "Selected items have no waypoints")
            case .both:
                return language.isGerman
                    ? (selectedSourceCount == 1 ? "Ausgewählter Eintrag hat keinen exportierbaren Karteninhalt" : "Ausgewählte Einträge haben keinen exportierbaren Karteninhalt")
                    : (selectedSourceCount == 1 ? "Selected item has no exportable map content" : "Selected items have no exportable map content")
            }
        case let .ready(selectedSourceCount, _, _, _, _, _):
            return language.isGerman
                ? "Exportiere \(selectedSourceCount) \(selectedSourceCount == 1 ? "Eintrag" : "Einträge") als \(format.rawValue)"
                : "Export \(selectedSourceCount) \(selectedSourceCount == 1 ? "item" : "items") as \(format.rawValue)"
        }
    }

    static func helperMessage(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        format: ExportFormat,
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode,
        language: AppLanguagePreference = .english
    ) -> String {
        switch readiness(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mode: mode
        ) {
        case .nothingSelected:
            switch mode {
            case .tracks:
                return language.isGerman
                    ? "Wähle mindestens einen importierten Tag oder gespeicherten Track mit Routen, um eine \(format.rawValue)-Datei vorzubereiten."
                    : "Choose at least one imported day or saved track with routes to prepare a \(format.rawValue) file."
            case .waypoints:
                return language.isGerman
                    ? "Wähle mindestens einen importierten Tag mit Besuchen oder Aktivitätsendpunkten, um eine \(format.rawValue)-Datei vorzubereiten."
                    : "Choose at least one imported day with visits or activity endpoints to prepare a \(format.rawValue) file."
            case .both:
                return language.isGerman
                    ? "Wähle importierte Historie oder gespeicherte Tracks mit Routen oder Wegpunkt-Positionen, um eine \(format.rawValue)-Datei vorzubereiten."
                    : "Choose imported history or saved tracks with routes or waypoint locations to prepare a \(format.rawValue) file."
            }
        case let .noExportableContent(selectedSourceCount):
            switch mode {
            case .tracks:
                return language.isGerman
                    ? (selectedSourceCount == 1
                        ? "Der ausgewählte Eintrag enthält keine Route mit nutzbaren GPS-Punkten."
                        : "Keiner der ausgewählten Einträge enthält Routen mit nutzbaren GPS-Punkten.")
                    : (selectedSourceCount == 1
                    ? "The selected item contains no route with usable GPS points."
                    : "None of the selected items contain routes with usable GPS points.")
            case .waypoints:
                return language.isGerman
                    ? (selectedSourceCount == 1
                        ? "Der ausgewählte Eintrag enthält keinen Besuch oder Aktivitätsendpunkt mit nutzbaren Koordinaten."
                        : "Keiner der ausgewählten Einträge enthält Besuche oder Aktivitätsendpunkte mit nutzbaren Koordinaten.")
                    : (selectedSourceCount == 1
                    ? "The selected item contains no visit or activity endpoint with usable coordinates."
                    : "None of the selected items contain visit or activity endpoints with usable coordinates.")
            case .both:
                return language.isGerman
                    ? (selectedSourceCount == 1
                        ? "Der ausgewählte Eintrag enthält weder Routengeometrie noch Wegpunkt-Positionen."
                        : "Keiner der ausgewählten Einträge enthält Routengeometrie oder Wegpunkt-Positionen.")
                    : (selectedSourceCount == 1
                    ? "The selected item contains neither route geometry nor waypoint locations."
                    : "None of the selected items contain route geometry or waypoint locations.")
            }
        case let .ready(selectedSourceCount, exportableSourceCount, routeCount, waypointCount, _, _):
            let contentSummary = exportedContentSummary(routeCount: routeCount, waypointCount: waypointCount, language: language)
            if exportableSourceCount < selectedSourceCount {
                return language.isGerman
                    ? "\(exportableSourceCount) von \(selectedSourceCount) ausgewählten Einträgen tragen \(contentSummary) bei. Quellen ohne passenden Inhalt bleiben aus der \(format.rawValue)-Datei heraus."
                    : "\(exportableSourceCount) of \(selectedSourceCount) selected items contribute \(contentSummary). Sources without matching content stay out of the \(format.rawValue) file."
            }
            return language.isGerman
                ? "\(contentSummary) werden in die \(format.rawValue)-Datei geschrieben."
                : "\(contentSummary) will be written to the \(format.rawValue) file."
        }
    }

    static func suggestedFilename(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat,
        mode: ExportMode,
        language: AppLanguagePreference = .english
    ) -> String {
        let sortedDates = ExportSelectionContent.filenameDates(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks
        )
        let modeSuffix: String
        switch mode {
        case .tracks:
            modeSuffix = ""
        case .waypoints:
            modeSuffix = "-waypoints"
        case .both:
            modeSuffix = "-mixed"
        }
        switch sortedDates.count {
        case 0:
            return "lh2gpx-export\(modeSuffix).\(format.fileExtension)"
        case 1:
            return "lh2gpx-\(sortedDates[0])\(modeSuffix).\(format.fileExtension)"
        default:
            guard let first = sortedDates.first, let last = sortedDates.last else {
                return "lh2gpx-export\(modeSuffix).\(format.fileExtension)"
            }
            return "lh2gpx-\(first)_to_\(last)\(modeSuffix).\(format.fileExtension)"
        }
    }

    static func filenameMessage(
        selection: ExportSelectionState,
        summaries: [DaySummary],
        recordedTracks: [RecordedTrack],
        format: ExportFormat,
        mode: ExportMode,
        language: AppLanguagePreference = .english
    ) -> String {
        let filename = suggestedFilename(
            selection: selection,
            summaries: summaries,
            recordedTracks: recordedTracks,
            format: format,
            mode: mode
        )
        return language.isGerman
            ? "Vorgeschlagener Dateiname: \(filename) (\(format.fileExtension.uppercased()))."
            : "Suggested filename: \(filename) (\(format.fileExtension.uppercased()))."
    }

    // MARK: - Checkout UI helpers

    /// Short summary label for the sticky bottom bar, e.g. "3 items · GPX".
    /// Returns an empty string when nothing is selected.
    static func bottomBarSummary(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode,
        format: ExportFormat,
        language: AppLanguagePreference = .english
    ) -> String {
        let snapshot = ExportSelectionContent.snapshot(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mode: mode
        )
        guard snapshot.selectedSourceCount > 0 else { return "" }
        let count = snapshot.selectedSourceCount
        let sourceLabel = language.isGerman
            ? "\(count) \(count == 1 ? "Eintrag" : "Einträge")"
            : "\(count) item\(count == 1 ? "" : "s")"
        return "\(sourceLabel) · \(format.rawValue)"
    }

    /// Human-readable reason why the export button is disabled, or nil when ready.
    static func disabledReason(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode,
        language: AppLanguagePreference = .english
    ) -> String? {
        switch readiness(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mode: mode
        ) {
        case .ready:
            return nil
        case .nothingSelected:
            return language.isGerman
                ? "Keine exportierbaren Daten ausgewählt"
                : "No exportable data selected"
        case .noExportableContent:
            switch mode {
            case .tracks:
                return language.isGerman
                    ? "Keine exportierbaren Routen in der Auswahl"
                    : "No exportable routes selected"
            case .waypoints:
                return language.isGerman
                    ? "Keine Wegpunkte in der Auswahl"
                    : "No waypoints in selection"
            case .both:
                return language.isGerman
                    ? "Kein exportierbarer Inhalt in der Auswahl"
                    : "No exportable content selected"
            }
        }
    }

    private static func exportedContentSummary(routeCount: Int, waypointCount: Int, language: AppLanguagePreference) -> String {
        var parts: [String] = []
        if routeCount > 0 {
            if language.isGerman {
                parts.append("\(routeCount) \(routeCount == 1 ? "Route" : "Routen")")
            } else {
                parts.append("\(routeCount) route\(routeCount == 1 ? "" : "s")")
            }
        }
        if waypointCount > 0 {
            if language.isGerman {
                parts.append("\(waypointCount) \(waypointCount == 1 ? "Wegpunkt" : "Wegpunkte")")
            } else {
                parts.append("\(waypointCount) waypoint\(waypointCount == 1 ? "" : "s")")
            }
        }
        return parts.joined(separator: language.isGerman ? " und " : " and ")
    }
}
