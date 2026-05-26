#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

/// Density heatmap with perceptual palette, log-scale aggregation, and
/// soft radial-gradient cells. Replaces the previous rainbow + flat-fill
/// rendering which produced bullseye target rings on country zoom.
@available(iOS 17.0, macOS 14.0, *)
public struct AppHeatmapView: View {
    private let export: AppExport
    @EnvironmentObject private var preferences: AppPreferences

    @State private var model: AppHeatmapModel
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isFirstLoad = true

    public init(export: AppExport) {
        self.export = export
        self._model = State(initialValue: AppHeatmapModel(export: export))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    public var body: some View {
        mapView
            .overlay(alignment: .topTrailing) {
                if model.hasData {
                    MapLayerMenu(configuration: MapLayerMenu.Configuration(
                        showsHeatmapControls: true,
                        fitToData: model.dataRegion == nil ? nil : fitToData
                    ))
                    .padding(12)
                    .accessibilityIdentifier("heatmap.layerMenu")
                }
            }
            .overlay(alignment: .bottom) {
                if model.isCalculating {
                    calculatingOverlay
                }
            }
            .overlay(alignment: .bottomLeading) {
                if model.hasData {
                    statsBadge
                }
            }
        .animation(.easeInOut(duration: 0.25), value: model.visibleCells.count)
        .onAppear {
            if isFirstLoad {
                model.startPrecomputation(scale: preferences.heatmapScale)
                isFirstLoad = false
            }
        }
        .onChange(of: model.initialCenter) { _, newCenter in
            if let center = newCenter {
                seedInitialViewport(center: center)
            }
        }
        .onChange(of: preferences.heatmapScale) { _, newScale in
            model.updateScale(newScale)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .accessibilityIdentifier(AppAccessibilityID.Map.heatmapRoot)
    }

    // MARK: - Map

    @ViewBuilder
    private var mapView: some View {
        Map(position: $mapPosition) {
            ForEach(model.visibleCells) { cell in
                MapPolygon(coordinates: scaledPolygonCoordinates(for: cell))
                    .foregroundStyle(cellGradient(for: cell))
            }
        }
        .mapStyle(densityMapStyle)
        .ignoresSafeArea(edges: .top)
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForRegion(context.region)
        }
    }

    private var densityMapStyle: MapStyle {
        // Train 9.2: route through `AppMapStyleResolver` so the heatmap
        // surface honours the user's `mapShowsRealisticElevation` preference
        // alongside the standard/hybrid/muted choice.
        AppMapStyleResolver.mapStyle(
            for: preferences.preferredMapStyle,
            showsRealisticElevation: preferences.mapShowsRealisticElevation
        )
    }

    /// Per-cell radial gradient: full colour at the centre fading to
    /// transparent at the polygon's bounding-rect edge. Combined with
    /// generous tile-span overlap, this produces a continuous glow field
    /// instead of a tiled mosaic — and hard hex edges effectively disappear.
    private func cellGradient(for cell: HeatCell) -> RadialGradient {
        let alpha = HeatmapVisualStyle.effectiveOpacity(
            normalizedIntensity: cell.normalizedIntensity,
            overlayOpacity: preferences.heatmapOpacity,
            lod: cell.lod
        )
        let position = HeatmapVisualStyle.colorPosition(for: cell.normalizedIntensity)
        let core = HeatmapPalette.color(for: position, palette: preferences.heatmapPalette)
        // Dark-mode polish: lift the inner stop (×1.3) and mid stop (×0.65)
        // so low-intensity cells remain visible against the dark map surface
        // without saturating high-intensity hotspots (capped in
        // `effectiveOpacity`).
        let innerAlpha = min(alpha * 1.3, 1.0)
        let midAlpha = min(alpha * 0.65, 1.0)
        return RadialGradient(
            colors: [core.opacity(innerAlpha), core.opacity(midAlpha), core.opacity(0.0)],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }

    // MARK: - Calculating overlay

    @ViewBuilder
    private var calculatingOverlay: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(LH2GPXTheme.LiquidGlass.trackPrimary)
            Text(t("Computing heatmap…"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
        )
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heatmap.computing")
        .accessibilityLabel(t("Computing heatmap"))
        .accessibilityValue(Text(t("In progress")))
    }

    // MARK: - Stats badge (bottom-leading info chip)

    @ViewBuilder
    private var statsBadge: some View {
        if !statsDescription.isEmpty {
            Text(statsDescription)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("heatmap.statsBadge")
                .accessibilityLabel(statsAccessibilityLabel)
                .accessibilityHint(Text(t("Total points and active day count for the current heatmap view. Adjust the date range or filters to recompute.")))
        }
    }

    private var statsAccessibilityLabel: String {
        let s = model.stats
        let pointsLabel = "\(formatCount(s.totalPoints)) \(t("points"))"
        let daysLabel = "\(s.dayCount) " + (s.dayCount == 1 ? t("day") : t("days"))
        return "\(pointsLabel), \(daysLabel)"
    }

    private var statsDescription: String {
        let s = model.stats
        guard s.totalPoints > 0 else { return "" }
        let pointsLabel = formatCount(s.totalPoints) + " " + t("points")
        let daysLabel = "\(s.dayCount) " + (s.dayCount == 1 ? t("day") : t("days"))
        if let first = s.firstDate, let last = s.lastDate, first != last {
            return "\(pointsLabel) · \(daysLabel)\n\(first) – \(last)"
        }
        return "\(pointsLabel) · \(daysLabel)"
    }

    private static let baseCountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func formatCount(_ value: Int) -> String {
        let formatter = Self.baseCountFormatter
        formatter.locale = preferences.appLocale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Helpers

    private func seedInitialViewport(center: CLLocationCoordinate2D) {
        if let region = model.dataRegion {
            mapPosition = .region(region)
            model.updateForRegion(region)
            return
        }

        let fallback = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        mapPosition = .region(fallback)
        model.updateForRegion(fallback)
    }

    private func fitToData() {
        guard let region = model.dataRegion else { return }
        mapPosition = .region(region)
        model.updateForRegion(region)
    }

    private func scaledPolygonCoordinates(for cell: HeatCell) -> [CLLocationCoordinate2D] {
        let stepLat = cell.cellSpan * preferences.heatmapRadius.scale
        let latRad = cell.coordinate.latitude * .pi / 180.0
        let lonScale = max(cos(latRad), 0.05)
        let stepLon = stepLat / lonScale
        return HeatmapGridBuilder.polygonCoordinates(
            centerLat: cell.coordinate.latitude,
            centerLon: cell.coordinate.longitude,
            stepLat: stepLat,
            stepLon: stepLon
        )
    }
}

// MARK: - Radius preset (iOS-only render-time helper)
//
// `AppHeatmapRadiusPreset` itself lives in HeatmapPreferenceEnums.swift so
// the AppSupport target compiles on Linux. The `scale` multiplier is only
// meaningful inside the SwiftUI render pipeline and stays here.

extension AppHeatmapRadiusPreset {
    var scale: Double {
        switch self {
        case .compact:  return 0.88
        case .balanced: return 1.00
        case .wide:     return 1.16
        }
    }
}

#endif
