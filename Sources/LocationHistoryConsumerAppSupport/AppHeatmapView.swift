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
        ZStack(alignment: .topTrailing) {
            mapView
            if model.hasData {
                MapLayerMenu(configuration: MapLayerMenu.Configuration(
                    showsHeatmapControls: true,
                    fitToData: model.dataRegion == nil ? nil : fitToData
                ))
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
            if model.isCalculating {
                calculatingOverlay
            }
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
        .onMapCameraChange(frequency: .continuous) { context in
            model.debounceUpdateForRegion(context.region)
        }
    }

    private var densityMapStyle: MapStyle {
        if preferences.preferredMapStyle.isHybrid { return .hybrid }
        return .standard()
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
        return RadialGradient(
            colors: [core.opacity(alpha), core.opacity(alpha * 0.45), core.opacity(0.0)],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }

    // MARK: - Calculating overlay

    @ViewBuilder
    private var calculatingOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(t("Computing heatmap…"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .padding()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Stats badge (bottom-leading info chip)

    @ViewBuilder
    private var statsBadge: some View {
        VStack {
            Spacer()
            HStack {
                if !statsDescription.isEmpty {
                    Text(statsDescription)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
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

    private func formatCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
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

// MARK: - Radius preset

public enum AppHeatmapRadiusPreset: String, CaseIterable, Identifiable, Sendable {
    case compact
    case balanced
    case wide

    public var id: String { rawValue }

    var scale: Double {
        switch self {
        case .compact:  return 0.88
        case .balanced: return 1.00
        case .wide:     return 1.16
        }
    }

    public var labelKey: String {
        switch self {
        case .compact:  return "Compact"
        case .balanced: return "Standard"
        case .wide:     return "Wide"
        }
    }
}

#endif
