#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

struct MapMetricPresentation: Identifiable, Equatable {
    let id: String
    let icon: String
    let text: String
    let accessibilityLabel: String
}

struct MapLegendItemPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let activityType: String?
    let isOverflow: Bool
}

struct MapSectionPresentation: Equatable {
    let metrics: [MapMetricPresentation]
    let legendItems: [MapLegendItemPresentation]
    let note: String?
}

enum MapPalette {
    static func visitColor(for semanticType: String?) -> Color {
        switch (semanticType ?? "").uppercased() {
        case "HOME": return .blue
        case "WORK": return .indigo
        case "CAFE", "RESTAURANT", "FOOD": return .orange
        case "PARK", "NATURE", "GARDEN": return .green
        case "LEISURE", "GYM", "SPORT", "FITNESS": return .teal
        case "EVENT", "CONCERT": return .yellow
        case "STAY", "HOTEL", "ACCOMMODATION": return .mint
        default: return .red
        }
    }

    static func routeColor(for activityType: String?) -> Color {
        switch (activityType ?? "").uppercased() {
        case "WALKING": return .green
        case "CYCLING": return .teal
        case "RUNNING": return .red
        case "IN PASSENGER VEHICLE": return .gray
        case "IN BUS": return .orange
        case "IN TRAIN", "IN SUBWAY": return .purple
        case "FLYING": return .blue
        case "LIVE TRACK": return .accentColor
        default: return .blue
        }
    }
}

enum MapPresentation {
    static func daySection(
        detail: DayDetailViewState,
        mapData: DayMapData,
        unit: AppDistanceUnitPreference
    ) -> MapSectionPresentation {
        let plottedPointCount = mapData.pathOverlays.reduce(0) { partialResult, overlay in
            partialResult + overlay.coordinates.count
        }
        let plottedDistance = mapData.pathOverlays.compactMap(\.distanceM)
            .filter { $0.isFinite && $0 > 0 }
            .reduce(0, +)
        let skippedVisitCount = max(0, detail.visits.count - mapData.visitAnnotations.count)
        let skippedRouteCount = max(0, detail.paths.count - mapData.pathOverlays.count)

        var metrics: [MapMetricPresentation] = []
        if !mapData.visitAnnotations.isEmpty {
            let count = mapData.visitAnnotations.count
            metrics.append(
                MapMetricPresentation(
                    id: "pins",
                    icon: "mappin.and.ellipse",
                    text: "\(count) \(count == 1 ? "pin" : "pins")",
                    accessibilityLabel: "\(count) visit \(count == 1 ? "pin" : "pins") on the map"
                )
            )
        }
        if !mapData.pathOverlays.isEmpty {
            let count = mapData.pathOverlays.count
            metrics.append(
                MapMetricPresentation(
                    id: "routes",
                    icon: "location.north.line",
                    text: "\(count) \(count == 1 ? "route" : "routes")",
                    accessibilityLabel: "\(count) plotted \(count == 1 ? "route" : "routes") on the map"
                )
            )
        }
        if plottedPointCount > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "points",
                    icon: "point.3.filled.connected.trianglepath.dotted",
                    text: "\(plottedPointCount) pts",
                    accessibilityLabel: "\(plottedPointCount) plotted route points"
                )
            )
        }
        if plottedDistance > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "distance",
                    icon: "ruler",
                    text: formatDistance(plottedDistance, unit: unit),
                    accessibilityLabel: "\(formatDistance(plottedDistance, unit: unit)) of plotted route distance"
                )
            )
        }

        let dominantMode = dominantRouteMode(
            routes: mapData.pathOverlays.map {
                RouteModeSource(activityType: $0.activityType, distanceM: $0.distanceM)
            }
        )
        var noteParts: [String] = []
        if !mapData.visitAnnotations.isEmpty && !mapData.pathOverlays.isEmpty {
            noteParts.append("Pins show imported visits and lines show imported route geometry.")
        } else if !mapData.visitAnnotations.isEmpty {
            noteParts.append("Only imported visits have usable coordinates on this day.")
        } else if !mapData.pathOverlays.isEmpty {
            noteParts.append("Only imported route geometry has usable coordinates on this day.")
        }
        if let dominantMode {
            noteParts.append("\(dominantMode) dominates the plotted movement.")
        }
        if skippedVisitCount > 0 || skippedRouteCount > 0 {
            var skippedParts: [String] = []
            if skippedVisitCount > 0 {
                skippedParts.append("\(skippedVisitCount) \(skippedVisitCount == 1 ? "visit is" : "visits are")")
            }
            if skippedRouteCount > 0 {
                skippedParts.append("\(skippedRouteCount) \(skippedRouteCount == 1 ? "route is" : "routes are")")
            }
            noteParts.append("\(skippedParts.joined(separator: " and ")) omitted because coordinates are missing or too short.")
        }

        return MapSectionPresentation(
            metrics: metrics,
            legendItems: routeLegendItems(
                from: mapData.pathOverlays.map {
                    RouteModeSource(activityType: $0.activityType, distanceM: $0.distanceM)
                }
            ),
            note: noteParts.isEmpty ? nil : noteParts.joined(separator: " ")
        )
    }

    static func exportPreview(
        _ previewData: ExportPreviewData,
        unit: AppDistanceUnitPreference
    ) -> MapSectionPresentation {
        let routeCount = previewData.pathOverlays.count
        let pointCount = previewData.pathOverlays.reduce(0) { partialResult, overlay in
            partialResult + overlay.coordinates.count
        }
        let plottedDistance = previewData.pathOverlays.compactMap(\.distanceM)
            .filter { $0.isFinite && $0 > 0 }
            .reduce(0, +)

        var metrics: [MapMetricPresentation] = []
        let sourceCount = previewData.selectedSourceCount
        if sourceCount > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "sources",
                    icon: "tray.full",
                    text: "\(sourceCount) \(sourceCount == 1 ? "source" : "sources")",
                    accessibilityLabel: "\(sourceCount) selected \(sourceCount == 1 ? "source" : "sources") in the preview"
                )
            )
        }
        if routeCount > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "routes",
                    icon: "location.north.line",
                    text: "\(routeCount) \(routeCount == 1 ? "route" : "routes")",
                    accessibilityLabel: "\(routeCount) preview \(routeCount == 1 ? "route" : "routes")"
                )
            )
        }
        if pointCount > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "points",
                    icon: "point.3.filled.connected.trianglepath.dotted",
                    text: "\(pointCount) pts",
                    accessibilityLabel: "\(pointCount) route points in the preview"
                )
            )
        }
        if plottedDistance > 0 {
            metrics.append(
                MapMetricPresentation(
                    id: "distance",
                    icon: "ruler",
                    text: formatDistance(plottedDistance, unit: unit),
                    accessibilityLabel: "\(formatDistance(plottedDistance, unit: unit)) of preview distance"
                )
            )
        }

        let dominantMode = dominantRouteMode(
            routes: previewData.pathOverlays.map {
                RouteModeSource(activityType: $0.activityType, distanceM: $0.distanceM)
            }
        )
        var sourceParts: [String] = []
        if previewData.importedDayCount > 0 {
            sourceParts.append("\(previewData.importedDayCount) imported \(previewData.importedDayCount == 1 ? "day" : "days")")
        }
        if previewData.savedTrackCount > 0 {
            sourceParts.append("\(previewData.savedTrackCount) saved \(previewData.savedTrackCount == 1 ? "track" : "tracks")")
        }

        var note = sourceParts.isEmpty
            ? nil
            : "Preview uses only exportable route geometry from \(sourceParts.joined(separator: " and "))."
        if let dominantMode {
            let dominantSentence = "\(dominantMode) contributes the strongest visible route context."
            note = note.map { "\($0) \(dominantSentence)" } ?? dominantSentence
        }

        return MapSectionPresentation(
            metrics: metrics,
            legendItems: routeLegendItems(
                from: previewData.pathOverlays.map {
                    RouteModeSource(activityType: $0.activityType, distanceM: $0.distanceM)
                }
            ),
            note: note
        )
    }

    private struct RouteModeSource {
        let activityType: String?
        let distanceM: Double?
    }

    private static func dominantRouteMode(routes: [RouteModeSource]) -> String? {
        let totals = aggregatedRouteModes(from: routes)
        guard let best = totals.first else {
            return nil
        }
        return displayNameForActivityType(best.activityType, default: "Routes")
    }

    private static func routeLegendItems(from routes: [RouteModeSource]) -> [MapLegendItemPresentation] {
        let totals = aggregatedRouteModes(from: routes)
        guard !totals.isEmpty else {
            return []
        }

        let visible = totals.prefix(3)
        var items = visible.map { mode in
            MapLegendItemPresentation(
                id: mode.key,
                title: displayNameForActivityType(mode.activityType, default: "Route"),
                activityType: mode.activityType,
                isOverflow: false
            )
        }

        if totals.count > visible.count {
            let overflowCount = totals.count - visible.count
            items.append(
                MapLegendItemPresentation(
                    id: "overflow",
                    title: "+\(overflowCount) more",
                    activityType: nil,
                    isOverflow: true
                )
            )
        }

        return items
    }

    private static func aggregatedRouteModes(from routes: [RouteModeSource]) -> [(key: String, activityType: String?, distanceM: Double, count: Int)] {
        var totals: [String: (activityType: String?, distanceM: Double, count: Int)] = [:]

        for route in routes {
            let trimmed = route.activityType?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = (trimmed?.isEmpty == false ? trimmed! : "UNKNOWN").uppercased()
            let distance = route.distanceM?.isFinite == true ? max(route.distanceM ?? 0, 0) : 0
            let current = totals[key] ?? (activityType: trimmed, distanceM: 0, count: 0)
            totals[key] = (
                activityType: current.activityType ?? trimmed,
                distanceM: current.distanceM + distance,
                count: current.count + 1
            )
        }

        return totals.map { key, value in
            (key: key, activityType: value.activityType, distanceM: value.distanceM, count: value.count)
        }
        .sorted { lhs, rhs in
            if lhs.distanceM != rhs.distanceM {
                return lhs.distanceM > rhs.distanceM
            }
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return displayNameForActivityType(lhs.activityType, default: "Route")
                < displayNameForActivityType(rhs.activityType, default: "Route")
        }
    }
}

struct MapSectionSupplementaryView: View {
    let presentation: MapSectionPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !presentation.metrics.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)], spacing: 8) {
                    ForEach(presentation.metrics) { metric in
                        MapMetricChipView(metric: metric)
                    }
                }
            }

            if !presentation.legendItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Legend")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(presentation.legendItems) { item in
                            MapLegendChipView(item: item)
                        }
                    }
                }
            }

            if let note = presentation.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MapMetricChipView: View {
    let metric: MapMetricPresentation

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(metric.text)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilityLabel)
    }
}

private struct MapLegendChipView: View {
    let item: MapLegendItemPresentation

    var body: some View {
        HStack(spacing: 7) {
            if item.isOverflow {
                Image(systemName: "ellipsis")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(MapPalette.routeColor(for: item.activityType))
                    .frame(width: 8, height: 8)
            }

            Text(item.title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.06))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.isOverflow ? item.title : "Legend item: \(item.title)")
    }
}

#endif
