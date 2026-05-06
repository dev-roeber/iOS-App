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
    @State private var isPanelExpanded = false

    public init(export: AppExport) {
        self.export = export
        self._model = State(initialValue: AppHeatmapModel(export: export))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    public var body: some View {
        ZStack {
            mapView
            if model.isCalculating {
                calculatingOverlay
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.hasData {
                controlsPanel
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.visibleCells.count)
        .animation(.easeInOut(duration: 0.25), value: isPanelExpanded)
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

    // MARK: - Controls panel (collapsible)

    @ViewBuilder
    private var controlsPanel: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 6)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 10) {
                statsHeader
                opacitySlider
                if isPanelExpanded {
                    radiusPicker
                    palettePicker
                    scalePicker
                }
                densityLegend
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            // Tap target for the entire drag-handle area.
            Color.clear
                .frame(height: 22)
                .contentShape(Rectangle())
                .onTapGesture { isPanelExpanded.toggle() }
                .accessibilityLabel(Text(isPanelExpanded ? t("Collapse controls") : t("Expand controls")))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: Color.black.opacity(0.10), radius: 14, y: 6)
        .controlSize(.small)
    }

    @ViewBuilder
    private var statsHeader: some View {
        HStack(spacing: 10) {
            Button(action: fitToData) {
                Label(t("Fit to data"), systemImage: "arrow.up.left.and.arrow.down.right")
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .disabled(model.dataRegion == nil)
            .accessibilityLabel(Text(t("Fit to data")))

            Button(action: cycleMapStyle) {
                Image(systemName: preferences.preferredMapStyle.isHybrid ? "globe.europe.africa.fill" : "map")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityLabel(Text(t("Toggle map style")))

            Spacer(minLength: 6)

            Text(statsDescription)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
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

    @ViewBuilder
    private var opacitySlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t("Opacity"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int((preferences.heatmapOpacity * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $preferences.heatmapOpacity, in: 0.15...1.0)
        }
    }

    @ViewBuilder
    private var radiusPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("Radius"))
                .font(.caption.weight(.semibold))
            chipRow(items: AppHeatmapRadiusPreset.allCases) { preset in
                preferences.heatmapRadius == preset
            } action: { preset in
                preferences.heatmapRadius = preset
            } label: { preset in
                t(preset.labelKey)
            }
        }
    }

    @ViewBuilder
    private var palettePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("Palette"))
                .font(.caption.weight(.semibold))
            chipRow(items: AppHeatmapPalettePreference.allCases) { palette in
                preferences.heatmapPalette == palette
            } action: { palette in
                preferences.heatmapPalette = palette
            } label: { palette in
                t(palette.labelKey)
            }
        }
    }

    @ViewBuilder
    private var scalePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("Scale"))
                .font(.caption.weight(.semibold))
            chipRow(items: AppHeatmapScalePreference.allCases) { scale in
                preferences.heatmapScale == scale
            } action: { scale in
                preferences.heatmapScale = scale
            } label: { scale in
                t(scale.labelKey)
            }
        }
    }

    @ViewBuilder
    private func chipRow<Item: Hashable & Identifiable>(
        items: [Item],
        isSelected: @escaping (Item) -> Bool,
        action: @escaping (Item) -> Void,
        label: @escaping (Item) -> String
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    Text(label(item))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected(item)
                                ? Color.accentColor.opacity(0.16)
                                : Color.secondary.opacity(0.08)
                        )
                        .foregroundStyle(isSelected(item) ? Color.accentColor : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var densityLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t("Low density"))
                Spacer()
                Text(t("High density"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            LinearGradient(
                colors: [
                    HeatmapPalette.color(for: 0.05, palette: preferences.heatmapPalette).opacity(0.55),
                    HeatmapPalette.color(for: 0.25, palette: preferences.heatmapPalette).opacity(0.75),
                    HeatmapPalette.color(for: 0.50, palette: preferences.heatmapPalette).opacity(0.88),
                    HeatmapPalette.color(for: 0.78, palette: preferences.heatmapPalette).opacity(0.95),
                    HeatmapPalette.color(for: 1.00, palette: preferences.heatmapPalette),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private func cycleMapStyle() {
        preferences.preferredMapStyle = preferences.preferredMapStyle.isHybrid ? .standard : .hybrid
    }

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
