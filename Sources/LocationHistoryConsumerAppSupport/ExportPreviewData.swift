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
            ? ExportWaypointExtractor.waypoints(from: exportDays).compactMap { wp -> DayMapVisitAnnotation? in
                // Phase Map-Train 2: drop NaN/Inf/sentinel coords at the
                // Foundation layer so `computeRegion` does not produce a NaN
                // center and the MapKit-side renderer cannot be handed an
                // invalid `CLLocationCoordinate2D`.
                guard CoordinateValidity.isValid(latitude: wp.latitude, longitude: wp.longitude) else { return nil }
                return DayMapVisitAnnotation(
                    coordinate: DayMapCoordinate(lat: wp.latitude, lon: wp.longitude),
                    semanticType: wp.detail ?? wp.category,
                    startTime: wp.time,
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
                    // Phase Map-Train 2: NaN/Inf/sentinel coords werden hier
                    // gemeinsam mit ihrem parallelen Timestamp verworfen, damit
                    // Alignment für spätere Speed-Layer / Region-Bounds erhalten
                    // bleibt.
                    let rawCount = path.points.count
                    guard rawCount >= 2 else { return nil }
                    var coordinates: [DayMapCoordinate] = []
                    coordinates.reserveCapacity(rawCount)
                    var timestamps: [String?] = []
                    timestamps.reserveCapacity(rawCount)
                    for point in path.points {
                        guard CoordinateValidity.isValid(latitude: point.lat, longitude: point.lon) else { continue }
                        coordinates.append(DayMapCoordinate(lat: point.lat, lon: point.lon))
                        timestamps.append(point.time)
                    }
                    guard coordinates.count >= 2 else { return nil }
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
