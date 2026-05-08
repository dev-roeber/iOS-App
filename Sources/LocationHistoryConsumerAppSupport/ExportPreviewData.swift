import Foundation
import LocationHistoryConsumer

struct ExportPreviewData: Equatable {
    let waypointAnnotations: [DayMapVisitAnnotation]
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
        queryFilter: AppExportQueryFilter? = nil,
        mode: ExportMode,
        mutations: ImportedPathMutationSet = .empty
    ) -> ExportPreviewData {
        let exportDays = ExportSelectionContent.exportDays(
            importedExport: importedExport,
            selection: selection,
            recordedTracks: recordedTracks,
            queryFilter: queryFilter,
            mutations: mutations
        )

        let waypointAnnotations = mode.includesWaypoints
            ? ExportWaypointExtractor.waypoints(from: exportDays).map {
                DayMapVisitAnnotation(
                    coordinate: DayMapCoordinate(lat: $0.latitude, lon: $0.longitude),
                    semanticType: $0.detail ?? $0.category,
                    startTime: $0.time,
                    endTime: nil
                )
            }
            : []
        let pathOverlays = mode.includesTracks
            ? exportDays.flatMap { day in
                day.paths.compactMap { path -> DayMapPathOverlay? in
                    // Phase-10C: vorher zwei separate `path.points.map`-Iterationen
                    // (coordinates + timestamps). Eine einzige Iteration befüllt
                    // beide Arrays parallel — semantisch identisch, halbierte
                    // Allokation/Iteration auf MainThread bei langen Pfaden.
                    let count = path.points.count
                    guard count >= 2 else { return nil }
                    var coordinates: [DayMapCoordinate] = []
                    coordinates.reserveCapacity(count)
                    var timestamps: [String?] = []
                    timestamps.reserveCapacity(count)
                    for point in path.points {
                        coordinates.append(DayMapCoordinate(lat: point.lat, lon: point.lon))
                        timestamps.append(point.time)
                    }
                    return DayMapPathOverlay(
                        coordinates: coordinates,
                        activityType: path.activityType,
                        distanceM: path.distanceM,
                        timestamps: timestamps
                    )
                }
            }
            : []

        let allCoordinates = waypointAnnotations.map(\.coordinate) + pathOverlays.flatMap(\.coordinates)
        let fittedRegion = computeRegion(from: allCoordinates)

        return ExportPreviewData(
            waypointAnnotations: waypointAnnotations,
            pathOverlays: pathOverlays,
            fittedRegion: fittedRegion,
            hasMapContent: !waypointAnnotations.isEmpty || !pathOverlays.isEmpty,
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
