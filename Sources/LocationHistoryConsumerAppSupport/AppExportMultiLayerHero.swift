#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import CoreLocation
import LocationHistoryConsumer

// MARK: - View hierarchy (Export Multi-Layer redesign, Phase 3c)
//
// AppExportMultiLayerHero (portrait) — ZStack
//  ├── Map background (full-bleed, ~50 % hero) — AppExportPreviewMapView with
//  │   hidesBuiltInControls so the parent renders the custom overlays. The
//  │   built-in `MapLayerMenu` is intentionally suppressed; the Layer Panel
//  │   on the leading edge owns layer selection.
//  ├── overlay(.topLeading)  → LiveLayerPanel (Standard/Tempo/Höhe/Wetter)
//  ├── overlay(.topTrailing) → LiveControlStack (compass / + / − / locate)
//  └── safeAreaInset(.bottom)
//        └── LiveBottomSheet (drag-handle, status badges, format/mode pills)
//
// The hero is hosted inside `AppExportView.checkoutLayout`'s top-inset slot;
// the surrounding ScrollView and the bottomBar continue to live outside the
// hero region.
//
// All strings flow through the parent's `t(...)` localizer (passed in as
// `localized`). German strings reuse the existing AppLanguageSupport entries
// where possible (LAYERS, STATUS · LIVE MAP). New keys go to the translation
// table in this file's translations sweep when required.
// ReduceMotion is honored by the embedded LiveBottomSheet and LiveLayerPanel.

@available(iOS 17.0, macOS 14.0, *)
struct AppExportMultiLayerHero: View {
    let previewData: ExportPreviewData
    let review: ExportPresentation.ReviewSnapshot
    let selection: ExportSelectionState
    let summaries: [DaySummary]
    let liveTrackCount: Int
    let selectedFormat: ExportFormat
    let selectedMode: ExportMode

    @Binding var colorMode: AppMapTrackColorMode
    @Binding var showElevation: Bool
    @Binding var showWeather: Bool

    let localized: (String) -> String
    let isGerman: Bool
    let placeholder: () -> AnyView

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var didSeedCamera: Bool = false

    private func t(_ english: String) -> String { localized(english) }

    private var renderData: ExportPreviewRenderData {
        ExportPreviewRenderData(previewData: previewData)
    }

    /// Hero height ≈ 52 % of the screen on phones, clamped to a sensible
    /// range so very small or very large devices still get a usable hero.
    private var heroHeight: CGFloat {
        #if canImport(UIKit)
        let screenHeight = UIScreen.main.bounds.height
        let target = screenHeight * 0.52
        return min(max(target, 360), 620)
        #else
        return 460
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapBackground

            HStack(alignment: .top, spacing: 0) {
                LiveLayerPanel(
                    selected: $colorMode,
                    showWeather: $showWeather,
                    showElevation: $showElevation,
                    layersLabel: layersPanelLabel
                )
                .padding(.leading, 12)
                .padding(.top, lhDeviceTopSafeInset() + 12)
                .accessibilityIdentifier("export.hero.layerPanel")

                Spacer()

                LiveControlStack(
                    isFollowing: false,
                    onCompass: { fitToData() },
                    onZoomIn: { adjustMapZoom(factor: 0.5) },
                    onZoomOut: { adjustMapZoom(factor: 2.0) },
                    onLocate: { fitToData() },
                    onCompactToggle: { /* no compact mode in export hero */ },
                    isCompact: false
                )
                .padding(.trailing, 12)
                .padding(.top, lhDeviceTopSafeInset() + 12)
                .accessibilityIdentifier("export.hero.controlStack")
            }
        }
        .frame(height: heroHeight)
        .clipped()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomSheet
        }
        .onAppear { seedCameraIfNeeded() }
        .onChange(of: previewData) { _, _ in
            // Re-seed when the user changes selection so the map snaps to new
            // bounds even if the user had previously panned/zoomed manually.
            didSeedCamera = false
            seedCameraIfNeeded()
        }
    }

    // MARK: - Map background

    @ViewBuilder
    private var mapBackground: some View {
        if previewData.hasMapContent {
            AppExportPreviewMapView(
                previewData: previewData,
                fillContainer: true,
                mapControlTopPadding: 0,
                hidesBuiltInControls: true,
                mapPosition: $mapPosition
            )
        } else {
            ZStack {
                Color.secondary.opacity(0.10)
                placeholder()
            }
        }
    }

    // MARK: - Bottom Sheet

    private var bottomSheet: some View {
        LiveBottomSheet(
            headerCaption: t("STATUS · EXPORT MAP"),
            headlineText: headlineText,
            headlineTint: headlineTint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                statusBadgeRow
                    .accessibilityIdentifier("export.hero.statusBadges")
                Divider().opacity(0.35)
                formatAndModeRow
                    .accessibilityIdentifier("export.hero.formatModePills")
                if colorMode == .speed || showElevation {
                    Divider().opacity(0.35)
                    layerInsightStack
                        .accessibilityIdentifier("export.hero.layerInsights")
                }
            }
            .padding(.top, 4)
        }
        .accessibilityIdentifier("export.hero.bottomSheet")
    }

    private var headlineText: String {
        if selection.isEmpty {
            let hasSelectableItems = !summaries.isEmpty || liveTrackCount > 0
            return hasSelectableItems
                ? t("Nothing selected yet")
                : t("No selectable content")
        }
        let parts: [String] = [
            review.selectedDayCount > 0
                ? "\(review.selectedDayCount) \(t("days"))" : nil,
            review.selectedRecordedTrackCount > 0
                ? "\(review.selectedRecordedTrackCount) \(t("tracks"))" : nil
        ].compactMap { $0 }
        if parts.isEmpty { return t("Export ready") }
        return parts.joined(separator: " · ")
    }

    private var headlineTint: Color {
        selection.isEmpty ? .secondary : .primary
    }

    @ViewBuilder
    private var statusBadgeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selection.isEmpty {
                    let hasSelectableItems = !summaries.isEmpty || liveTrackCount > 0
                    LHStatusBadge(
                        title: hasSelectableItems ? t("Tap to choose") : t("Nothing selected"),
                        systemImage: hasSelectableItems ? "hand.tap" : "exclamationmark.triangle"
                    )
                } else {
                    if review.selectedDayCount > 0 {
                        LHStatusBadge(
                            title: "\(review.selectedDayCount) \(t("days"))",
                            systemImage: "calendar"
                        )
                    }
                    if review.selectedRecordedTrackCount > 0 {
                        LHStatusBadge(
                            title: "\(review.selectedRecordedTrackCount) \(t("tracks"))",
                            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                    if review.routeCount > 0 {
                        LHStatusBadge(
                            title: "\(review.routeCount) \(t("routes"))",
                            systemImage: "location.north.line"
                        )
                    }
                    if review.waypointCount > 0 {
                        LHStatusBadge(
                            title: "\(review.waypointCount) \(t("waypoints"))",
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var formatAndModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Format pill (read-only mirror; the canonical chooser is the
            // scrollable `formatCard` below the hero).
            HStack(spacing: 8) {
                Text(t("Format"))
                    .font(.caption2.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                LHFilterChip(
                    title: selectedFormat.rawValue.uppercased(),
                    systemImage: selectedFormat.systemImage,
                    isActive: true,
                    action: {}
                )
                .accessibilityIdentifier("export.hero.formatPill")
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Text(t("Mode"))
                    .font(.caption2.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                LHFilterChip(
                    title: t(modeTitle(selectedMode)),
                    systemImage: modeIcon(selectedMode),
                    isActive: true,
                    action: {}
                )
                .accessibilityIdentifier("export.hero.modePill")
                Spacer(minLength: 0)
            }
        }
    }

    private func modeIcon(_ mode: ExportMode) -> String {
        switch mode {
        case .tracks:    return "location.north.line"
        case .waypoints: return "mappin.and.ellipse"
        case .both:      return "map"
        }
    }

    private func modeTitle(_ mode: ExportMode) -> String {
        // Mirrors the rawValue used by the canonical chooser so the
        // localized lookup is identical.
        return mode.rawValue
    }

    private var layersPanelLabel: String {
        let standardActive = colorMode != .speed
        let speedActive = colorMode == .speed
        let count =
            (standardActive ? 1 : 0)
            + (speedActive ? 1 : 0)
            + (showElevation ? 1 : 0)
            + (showWeather ? 1 : 0)
        return "\(t("LAYERS")) \(count)/4"
    }

    // MARK: - Layer insight section
    //
    // When the user activates the Tempo or Höhe layer in the Layer Panel we
    // mirror the corresponding band component (`AppSpeedBandView` /
    // `AppElevationProfileView`) inside the bottom sheet so the export sheet
    // matches Live / DayDetail. Data is aggregated across all selected
    // export tracks. Speed samples are derived per-overlay via
    // `SpeedTrackBuilder.instantaneousSpeed` (using the per-point timestamps
    // surfaced by `ExportPreviewDataBuilder`). Elevation is not yet carried by
    // `DayMapPathOverlay`, so the elevation profile shows its empty-state
    // until a follow-up wires elevation into the preview pipeline.

    @ViewBuilder
    private var layerInsightStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            if colorMode == .speed {
                AppSpeedBandView(
                    speeds: aggregatedSpeedSamples,
                    unit: .metersPerSecond,
                    title: t("Tempo")
                )
                .accessibilityIdentifier("export.hero.speedBand")
            }
            if showElevation {
                AppElevationProfileView(
                    points: aggregatedElevationSamples,
                    title: t("Höhe")
                )
                .accessibilityIdentifier("export.hero.elevationProfile")
            }
        }
    }

    /// Aggregates speed samples across every selected export path overlay.
    /// Each overlay yields (timestamp, m/s) pairs derived from the great-circle
    /// distance between consecutive points divided by Δt. Overlays without
    /// per-point timestamps contribute nothing (empty-state).
    private var aggregatedSpeedSamples: [AppSpeedBandSample] {
        var result: [AppSpeedBandSample] = []
        for overlay in previewData.pathOverlays {
            let coords = overlay.coordinates
            let times = overlay.timestamps
            guard coords.count >= 2, times.count == coords.count else { continue }
            let parsedTimes: [Date?] = times.map { iso in
                guard let iso else { return nil }
                return Self.isoFormatter.date(from: iso) ?? Self.isoFallback.date(from: iso)
            }
            for index in 0..<(coords.count - 1) {
                guard let tA = parsedTimes[index], let tB = parsedTimes[index + 1] else { continue }
                let a = TrackSample(
                    coordinate: CLLocationCoordinate2D(latitude: coords[index].lat, longitude: coords[index].lon),
                    timestamp: tA
                )
                let b = TrackSample(
                    coordinate: CLLocationCoordinate2D(latitude: coords[index + 1].lat, longitude: coords[index + 1].lon),
                    timestamp: tB
                )
                if let speed = SpeedTrackBuilder.instantaneousSpeed(from: a, to: b) {
                    result.append(AppSpeedBandSample(timestamp: tB, speed: speed))
                }
            }
        }
        result.sort { $0.timestamp < $1.timestamp }
        return result
    }

    /// Elevation samples are not yet propagated through `DayMapPathOverlay`,
    /// so the export hero ships an empty array and the profile component
    /// renders its empty-state. Documented in the PR body as a follow-up.
    private var aggregatedElevationSamples: [AppElevationProfileSample] { [] }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Camera helpers

    private func seedCameraIfNeeded() {
        guard !didSeedCamera else { return }
        if let region = renderData.region {
            mapPosition = .region(region)
            didSeedCamera = true
        }
    }

    private func fitToData() {
        if let region = renderData.region {
            withAnimation { mapPosition = .region(region) }
        }
    }

    /// Approximates a single zoom step. We cannot read the active span back
    /// from `MapCameraPosition` reliably across iOS versions, so we anchor on
    /// the fitted region center and apply a sensible scaled span. When no
    /// fitted region is available this is a no-op — never traps.
    private func adjustMapZoom(factor: Double) {
        guard let region = renderData.region else { return }
        let scaledSpan = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta * factor, 0.0005),
            longitudeDelta: max(region.span.longitudeDelta * factor, 0.0005)
        )
        withAnimation {
            mapPosition = .region(
                MKCoordinateRegion(center: region.center, span: scaledSpan)
            )
        }
    }
}
#endif
