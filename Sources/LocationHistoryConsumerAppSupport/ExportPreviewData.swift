import Foundation
import LocationHistoryConsumer

struct ExportPreviewData: Equatable {
    let pathOverlays: [DayMapPathOverlay]
    let fittedRegion: DayMapRegion?
    let hasMapContent: Bool
    let importedDayCount: Int
    let savedTrackCount: Int

    var selectedSourceCount: Int {
        importedDayCount + savedTrackCount
    }
}

enum ExportPreviewDataBuilder {
    static func previewData(
        importedExport: AppExport?,
        selection: ExportSelectionState,
        recordedTracks: [RecordedTrack],
        queryFilter: AppExportQueryFilter? = nil
    ) -> ExportPreviewData {
        let exportDays = ExportSelectionContent.exportDays(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter
        )

        let pathOverlays = exportDays.flatMap { day in
            day.paths.compactMap { path -> DayMapPathOverlay? in
                let coordinates = path.points.map { DayMapCoordinate(lat: $0.lat, lon: $0.lon) }
                guard coordinates.count >= 2 else {
                    return nil
                }
                return DayMapPathOverlay(
                    coordinates: coordinates,
                    activityType: path.activityType,
                    distanceM: path.distanceM
                )
            }
        }

        let allCoordinates = pathOverlays.flatMap(\.coordinates)
        let fittedRegion = computeRegion(from: allCoordinates)

        return ExportPreviewData(
            pathOverlays: pathOverlays,
            fittedRegion: fittedRegion,
            hasMapContent: !pathOverlays.isEmpty,
            importedDayCount: selection.selectedDayCount,
            savedTrackCount: selection.selectedRecordedTrackCount
        )
    }

    private static func computeRegion(from coordinates: [DayMapCoordinate]) -> DayMapRegion? {
        guard let first = coordinates.first else {
            return nil
        }

        var minLat = first.lat
        var maxLat = first.lat
        var minLon = first.lon
        var maxLon = first.lon

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.lat)
            maxLat = max(maxLat, coordinate.lat)
            minLon = min(minLon, coordinate.lon)
            maxLon = max(maxLon, coordinate.lon)
        }

        return DayMapRegion(
            centerLat: (minLat + maxLat) / 2,
            centerLon: (minLon + maxLon) / 2,
            spanLat: max((maxLat - minLat) * 1.4, 0.005),
            spanLon: max((maxLon - minLon) * 1.4, 0.005)
        )
    }
}
