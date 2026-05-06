#if canImport(SwiftUI) && canImport(MapKit)
import SwiftUI
import MapKit
import LocationHistoryConsumer

// MARK: - Overview Map Model

@available(iOS 17.0, macOS 14.0, *)
@Observable @MainActor
final class AppOverviewMapModel {
    var renderData: OverviewMapRenderData = .empty
    var dataRegion: MKCoordinateRegion?

    private var allCandidates: [OverviewMapPathCandidate] = []
    private var totalPointCount: Int = 0
    private var loadGeneration: UInt64 = 0
    private var overlayTask: Task<Void, Never>?

    init() {}

    /// Full data load: scans export once, caches all candidates, then builds initial overlays.
    /// Only called when the input data or filter changes (`.task(id: taskKey)`).
    /// Pan/zoom never re-triggers this scan — only `rebuildOverlays` is called on viewport change.
    func loadData(
        daySummaries: [DaySummary],
        content: AppSessionContent?,
        filter: AppExportQueryFilter?
    ) async {
        loadGeneration &+= 1
        let gen = loadGeneration
        overlayTask?.cancel()

        guard let content, !daySummaries.isEmpty else {
            allCandidates = []
            dataRegion = nil
            renderData = .empty
            return
        }

        renderData = .loading

        let dates = Set(daySummaries.map(\.date))
        let innerTask = Task.detached(priority: .userInitiated) {
            OverviewMapPreparation.scanCandidates(for: dates, export: content.export, filter: filter)
        }
        let scanned = await withTaskCancellationHandler(
            operation: { await innerTask.value },
            onCancel: { innerTask.cancel() }
        )

        guard !Task.isCancelled, gen == loadGeneration else { return }
        allCandidates = scanned.candidates
        dataRegion = scanned.dataRegion
        totalPointCount = scanned.totalPointCount

        rebuildOverlays(viewportRegion: nil)
    }

    /// Rebuilds the visible overlay set for a new camera region.
    /// Uses bounding-box intersection so long routes that cross the viewport
    /// are prioritised even when their midpoint is outside.
    /// No export re-scan; uses the cached candidate list from `loadData`.
    func updateForViewport(_ region: MKCoordinateRegion) {
        rebuildOverlays(viewportRegion: region)
    }

    /// Resets to full-data selection (call when the explore sheet is dismissed
    /// so the compact map reflects the full overview region again).
    func resetToFullView() {
        rebuildOverlays(viewportRegion: nil)
    }

    private func rebuildOverlays(viewportRegion: MKCoordinateRegion?) {
        overlayTask?.cancel()
        let candidates = allCandidates
        let pointCount = totalPointCount
        let dataReg = dataRegion
        let viewport = viewportRegion
        let gen = loadGeneration
        overlayTask = Task.detached(priority: .userInitiated) { [self] in
            let data = OverviewMapPreparation.buildOverlaysFromCandidates(
                candidates: candidates,
                totalPointCount: pointCount,
                dataRegion: dataReg,
                viewportRegion: viewport
            )
            guard !Task.isCancelled else { return }
            await MainActor.run { [self] in
                guard gen == self.loadGeneration else { return }
                self.renderData = data
            }
        }
    }
}

// MARK: - Scan Result

struct OverviewMapScanResult {
    let candidates: [OverviewMapPathCandidate]
    let dataRegion: MKCoordinateRegion?
    let totalPointCount: Int
}

// MARK: - Overview Tracks Map View

/// Interactive map showing all tracks in the active time range.
/// Supports zoom/pan, style switching, fit-to-data, and fullscreen explore mode.
@available(iOS 17.0, macOS 14.0, *)
struct AppOverviewTracksMapView: View {
    @EnvironmentObject private var preferences: AppPreferences

    let daySummaries: [DaySummary]
    let content: AppSessionContent?
    let queryFilter: AppExportQueryFilter?
    let fixedHeight: CGFloat?
    let showsFullscreenControl: Bool
    /// Top padding for the topTrailing map-control overlay.
    /// Callers that draw the map behind the status bar (e.g. Days hero map with
    /// `.ignoresSafeArea(edges: .top)`) must pass `safeAreaTop + N` here so the
    /// controls do not land in Dynamic Island / status bar.
    let mapControlTopPadding: CGFloat
    /// When `true`, render Globe + Fit-to-data + (optional) Fullscreen buttons
    /// stacked vertically (a column) instead of horizontally (a row).
    /// Use this when another set of overlay controls (e.g. the LHCollapsibleMapHeader
    /// chevron) already occupies the top-right corner — vertical layout puts the
    /// map controls cleanly below that header chevron rather than next to it.
    let verticalMapControls: Bool

    @State private var model = AppOverviewMapModel()
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialPosition = false
    @State private var isExpanded = false

    init(
        daySummaries: [DaySummary],
        content: AppSessionContent?,
        queryFilter: AppExportQueryFilter?,
        fixedHeight: CGFloat? = 200,
        showsFullscreenControl: Bool = true,
        mapControlTopPadding: CGFloat = 8,
        verticalMapControls: Bool = false
    ) {
        self.daySummaries = daySummaries
        self.content = content
        self.queryFilter = queryFilter
        self.fixedHeight = fixedHeight
        self.showsFullscreenControl = showsFullscreenControl
        self.mapControlTopPadding = mapControlTopPadding
        self.verticalMapControls = verticalMapControls
    }

    var body: some View {
        Group {
            if model.renderData.hasContent {
                compactMapView
            } else if model.renderData.isLoading {
                loadingPlaceholder
            } else {
                emptyPlaceholder
            }
        }
        .frame(height: fixedHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sheet(isPresented: $isExpanded, onDismiss: {
            // Reset viewport selection when sheet is dismissed so the compact map
            // reflects the full overview region, not the last-explored camera position.
            model.resetToFullView()
        }) {
            AppOverviewExploreSheet(model: model)
                .environmentObject(preferences)
        }
        .task(id: taskKey) {
            hasSetInitialPosition = false
            await model.loadData(
                daySummaries: daySummaries,
                content: content,
                filter: queryFilter
            )
        }
        .onChange(of: model.renderData.hasContent) { _, hasContent in
            if hasContent && !hasSetInitialPosition, let region = model.dataRegion {
                mapPosition = .region(region)
                hasSetInitialPosition = true
            }
        }
    }

    // MARK: - Map

    private var compactMapView: some View {
        Map(position: $mapPosition) {
            ForEach(Array(model.renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.overview * MapTrackStyle.haloMultiplier)
                    )
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        MapPalette.routeColor(for: path.activityType),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.overview)
                    )
            }
        }
        .mapStyle(mapStyle)
        // .onEnd fires once per gesture — sufficient for overlay rebuild;
        // .continuous is not used to avoid spurious rebuilds during smooth MapKit animations.
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForViewport(context.region)
        }
        .accessibilityLabel(mapAccessibilityLabel)
        .overlay(alignment: .topTrailing) {
            mapControlsStack
                .padding(.top, mapControlTopPadding)
                .padding(.trailing, 8)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomTrailing) { routeCountBadge }
        .overlay(alignment: .bottomLeading) { optimizedBadge }
    }

    // MARK: - Controls

    @ViewBuilder
    private var mapControlsStack: some View {
        let buttons: [AnyView] = [
            AnyView(mapControlButton(
                systemImage: styleToggleIcon,
                accessibilityLabel: t("Toggle map style")
            ) {
                preferences.preferredMapStyle = preferences.preferredMapStyle.isHybrid ? .standard : .hybrid
            }),
            AnyView(mapControlButton(
                systemImage: "location.viewfinder",
                accessibilityLabel: t("Fit to data")
            ) {
                if let region = model.dataRegion {
                    withAnimation { mapPosition = .region(region) }
                }
            })
        ]
        let fullscreenButton: AnyView? = showsFullscreenControl ? AnyView(mapControlButton(
            systemImage: "arrow.up.left.and.arrow.down.right",
            accessibilityLabel: t("Open fullscreen map")
        ) {
            isExpanded = true
        }) : nil

        if verticalMapControls {
            VStack(spacing: 6) {
                ForEach(0..<buttons.count, id: \.self) { idx in buttons[idx] }
                if let fb = fullscreenButton { fb }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(0..<buttons.count, id: \.self) { idx in buttons[idx] }
                if let fb = fullscreenButton { fb }
            }
        }
    }

    @ViewBuilder
    private func mapControlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var routeCountBadge: some View {
        Text("\(model.renderData.visibleRouteCount) \(t(model.renderData.visibleRouteCount == 1 ? "route" : "routes"))")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
            .padding(8)
    }

    @ViewBuilder
    private var optimizedBadge: some View {
        if model.renderData.isOptimized {
            let label = model.renderData.visibleRouteCount < model.renderData.totalRouteCount
                ? t("Simplified preview · export complete")
                : t("Optimized overview")
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.35))
                .clipShape(Capsule())
                .padding(8)
        }
    }

    // MARK: - Placeholders

    private var loadingPlaceholder: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Loading map…"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                Text(t("Analysing routes…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(t("No tracks in selected range"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Helpers

    private var taskKey: Int {
        OverviewMapTaskKey.make(daySummaries: daySummaries, queryFilter: queryFilter)
    }

    private var mapStyle: MapStyle {
        preferences.preferredMapStyle.isHybrid ? .hybrid : .standard
    }

    private var styleToggleIcon: String {
        preferences.preferredMapStyle.isHybrid ? "map" : "globe"
    }

    private var mapAccessibilityLabel: String {
        let count = model.renderData.visibleRouteCount
        if preferences.appLanguage.isGerman {
            if model.renderData.isOptimized {
                return "Optimierte Übersichtskarte mit \(count) dargestellten \(count == 1 ? "Route" : "Routen")"
            }
            return "Übersichtskarte mit \(count) \(count == 1 ? "Route" : "Routen")"
        }
        if model.renderData.isOptimized {
            return "Optimized overview map with \(count) displayed \(count == 1 ? "route" : "routes")"
        }
        return "Overview map with \(count) \(count == 1 ? "route" : "routes")"
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Explore Sheet

@available(iOS 17.0, macOS 14.0, *)
struct AppOverviewExploreSheet: View {
    let model: AppOverviewMapModel
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                if model.renderData.hasContent {
                    exploreMap
                } else if model.renderData.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(t("Loading map…"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(t("No tracks in selected range"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(t("Explore"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("Done")) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if let region = model.dataRegion {
                mapPosition = .region(region)
            }
        }
    }

    private var exploreMap: some View {
        Map(position: $mapPosition) {
            ForEach(Array(model.renderData.pathOverlays.enumerated()), id: \.offset) { _, path in
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        Color.white.opacity(MapTrackStyle.haloOpacity),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.overview * MapTrackStyle.haloMultiplier)
                    )
                MapPolyline(coordinates: path.coordinates)
                    .stroke(
                        MapPalette.routeColor(for: path.activityType),
                        style: MapTrackStyle.stroke(width: MapTrackStyle.Width.overview)
                    )
            }
        }
        .mapStyle(preferences.preferredMapStyle.isHybrid ? .hybrid : .standard)
        .onMapCameraChange(frequency: .onEnd) { context in
            model.updateForViewport(context.region)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                exploreControlButton(
                    systemImage: preferences.preferredMapStyle.isHybrid ? "map" : "globe",
                    accessibilityLabel: t("Toggle map style")
                ) {
                    preferences.preferredMapStyle = preferences.preferredMapStyle.isHybrid ? .standard : .hybrid
                }
                exploreControlButton(
                    systemImage: "location.viewfinder",
                    accessibilityLabel: t("Fit to data")
                ) {
                    if let region = model.dataRegion {
                        withAnimation { mapPosition = .region(region) }
                    }
                }
            }
            .padding(12)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(model.renderData.visibleRouteCount) \(t(model.renderData.visibleRouteCount == 1 ? "route" : "routes"))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                if model.renderData.isOptimized {
                    let label = model.renderData.visibleRouteCount < model.renderData.totalRouteCount
                        ? t("Simplified preview · export complete")
                        : t("Optimized overview")
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func exploreControlButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Render Data Models

struct OverviewMapPathOverlay: Equatable {
    let coordinates: [CLLocationCoordinate2D]
    let activityType: String?
}

struct OverviewMapRenderData {
    let pathOverlays: [OverviewMapPathOverlay]
    let region: MKCoordinateRegion?
    let totalRouteCount: Int
    let isOptimized: Bool
    let isLoading: Bool

    var hasContent: Bool { !pathOverlays.isEmpty }
    var visibleRouteCount: Int { pathOverlays.count }

    static let empty = OverviewMapRenderData(
        pathOverlays: [], region: nil, totalRouteCount: 0, isOptimized: false, isLoading: false
    )
    static let loading = OverviewMapRenderData(
        pathOverlays: [], region: nil, totalRouteCount: 0, isOptimized: false, isLoading: true
    )

    init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?, totalRouteCount: Int, isOptimized: Bool = false) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.totalRouteCount = totalRouteCount
        self.isOptimized = isOptimized
        self.isLoading = false
    }

    private init(pathOverlays: [OverviewMapPathOverlay], region: MKCoordinateRegion?, totalRouteCount: Int, isOptimized: Bool, isLoading: Bool) {
        self.pathOverlays = pathOverlays
        self.region = region
        self.totalRouteCount = totalRouteCount
        self.isOptimized = isOptimized
        self.isLoading = isLoading
    }
}

/// Loading phases exposed for tests and the loading UI.
enum OverviewMapLoadingPhase {
    case analyzing
    case building

    var descriptionKey: String {
        switch self {
        case .analyzing: return "Analysing routes…"
        case .building:  return "Building map…"
        }
    }
}

enum OverviewMapTaskKey {
    nonisolated static func make(daySummaries: [DaySummary], queryFilter: AppExportQueryFilter?) -> Int {
        var hasher = Hasher()
        hasher.combine(queryFilter)
        for summary in daySummaries {
            hasher.combine(summary.date)
            hasher.combine(summary.pathCount)
            hasher.combine(summary.exportablePathCount)
            hasher.combine(summary.totalPathPointCount)
            hasher.combine(summary.visitCount)
            hasher.combine(summary.activityCount)
        }
        return hasher.finalize()
    }
}

/// A route candidate with bounding box for viewport-intersection culling.
/// The bounding box ensures that long routes crossing the viewport edge are
/// prioritised even when their geographic midpoint is outside the visible area.
struct OverviewMapPathCandidate {
    let signature: Int
    let fullCoordinates: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let boundsMinLat: Double
    let boundsMaxLat: Double
    let boundsMinLon: Double
    let boundsMaxLon: Double
    let activityType: String?
    let score: Double
}

struct OverviewMapRenderProfile {
    let routeLimit: Int
    /// Hard cap on MapPolyline overlays sent to MapKit.
    /// Prevents freeze/crash for large datasets. Export data is never affected.
    let overlayLimit: Int
    let gridDimension: Int
    let maxRoutesPerCell: Int
    let simplificationEpsilonM: Double
    let maxPolylinePoints: Int

    static func resolve(routeCount: Int, totalPointCount: Int) -> OverviewMapRenderProfile {
        switch (routeCount, totalPointCount) {
        case let (routes, points) where routes > 500 || points > 150_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount, overlayLimit: 150,
                gridDimension: 12, maxRoutesPerCell: 2,
                simplificationEpsilonM: 140, maxPolylinePoints: 64
            )
        case let (routes, points) where routes > 240 || points > 60_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount, overlayLimit: 200,
                gridDimension: 10, maxRoutesPerCell: 3,
                simplificationEpsilonM: 100, maxPolylinePoints: 96
            )
        case let (routes, points) where routes > 120 || points > 30_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount, overlayLimit: 250,
                gridDimension: 9, maxRoutesPerCell: 4,
                simplificationEpsilonM: 70, maxPolylinePoints: 120
            )
        case let (routes, points) where routes > 60 || points > 15_000:
            return OverviewMapRenderProfile(
                routeLimit: routeCount, overlayLimit: 300,
                gridDimension: 8, maxRoutesPerCell: 6,
                simplificationEpsilonM: 50, maxPolylinePoints: 160
            )
        default:
            return OverviewMapRenderProfile(
                routeLimit: routeCount, overlayLimit: max(routeCount, 1),
                gridDimension: 6, maxRoutesPerCell: 6,
                simplificationEpsilonM: 30, maxPolylinePoints: 220
            )
        }
    }
}

// MARK: - Preparation

enum OverviewMapPreparation {

    // MARK: Scan phase — collect all path candidates from the export

    /// O(N) scan: iterates `export.data.days` once, returns all route candidates with bounding boxes.
    nonisolated static func scanCandidates(
        for dateSet: Set<String>,
        export: AppExport,
        filter: AppExportQueryFilter?
    ) -> OverviewMapScanResult {
        let allowedActivityTypes: Set<String>? = filter.flatMap { f in
            f.activityTypes.isEmpty ? nil : f.activityTypes
        }

        var candidates: [OverviewMapPathCandidate] = []
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        var hasAnyCoord = false
        var totalPointCount = 0
        let pointBudget = 2_000_000
        var iterationCount = 0

        outer: for day in export.data.days {
            guard dateSet.contains(day.date) else { continue }

            for path in day.paths {
                iterationCount += 1
                if iterationCount % 100 == 0, Task.isCancelled { break outer }
                if totalPointCount >= pointBudget { break outer }

                if let allowed = allowedActivityTypes {
                    guard let actType = path.activityType, allowed.contains(actType) else { continue }
                }

                let coordinates: [CLLocationCoordinate2D]
                var pathMinLat = Double.greatestFiniteMagnitude
                var pathMaxLat = -Double.greatestFiniteMagnitude
                var pathMinLon = Double.greatestFiniteMagnitude
                var pathMaxLon = -Double.greatestFiniteMagnitude

                if let flat = path.flatCoordinates, flat.count >= 4, flat.count.isMultiple(of: 2) {
                    var coords = [CLLocationCoordinate2D]()
                    coords.reserveCapacity(flat.count / 2)
                    var i = 0
                    while i < flat.count - 1 {
                        let lat = flat[i]; let lon = flat[i + 1]
                        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        if lat < minLat { minLat = lat }
                        if lat > maxLat { maxLat = lat }
                        if lon < minLon { minLon = lon }
                        if lon > maxLon { maxLon = lon }
                        if lat < pathMinLat { pathMinLat = lat }
                        if lat > pathMaxLat { pathMaxLat = lat }
                        if lon < pathMinLon { pathMinLon = lon }
                        if lon > pathMaxLon { pathMaxLon = lon }
                        hasAnyCoord = true
                        i += 2
                    }
                    coordinates = coords
                } else if path.points.count >= 2 {
                    var coords = [CLLocationCoordinate2D]()
                    coords.reserveCapacity(path.points.count)
                    for pt in path.points {
                        coords.append(CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lon))
                        if pt.lat < minLat { minLat = pt.lat }
                        if pt.lat > maxLat { maxLat = pt.lat }
                        if pt.lon < minLon { minLon = pt.lon }
                        if pt.lon > maxLon { maxLon = pt.lon }
                        if pt.lat < pathMinLat { pathMinLat = pt.lat }
                        if pt.lat > pathMaxLat { pathMaxLat = pt.lat }
                        if pt.lon < pathMinLon { pathMinLon = pt.lon }
                        if pt.lon > pathMaxLon { pathMaxLon = pt.lon }
                        hasAnyCoord = true
                    }
                    coordinates = coords
                } else {
                    continue
                }

                guard coordinates.count >= 2 else { continue }
                totalPointCount += coordinates.count

                let scoreBase = path.distanceM ?? approximateDistance(for: coordinates)
                let pointWeight = log(Double(max(coordinates.count, 2)))
                let midpointIndex = coordinates.count / 2
                var hasher = Hasher()
                hasher.combine(path.activityType)
                hasher.combine(coordinates.count)
                hasher.combine(path.distanceM ?? 0)
                hasher.combine(coordinates.first?.latitude ?? 0)
                hasher.combine(coordinates.first?.longitude ?? 0)
                hasher.combine(coordinates[midpointIndex].latitude)
                hasher.combine(coordinates[midpointIndex].longitude)
                hasher.combine(coordinates.last?.latitude ?? 0)
                hasher.combine(coordinates.last?.longitude ?? 0)

                candidates.append(OverviewMapPathCandidate(
                    signature: hasher.finalize(),
                    fullCoordinates: coordinates,
                    midpoint: coordinates[midpointIndex],
                    boundsMinLat: pathMinLat,
                    boundsMaxLat: pathMaxLat,
                    boundsMinLon: pathMinLon,
                    boundsMaxLon: pathMaxLon,
                    activityType: path.activityType,
                    score: scoreBase + pointWeight * 100
                ))
            }
        }

        let region: MKCoordinateRegion? = hasAnyCoord ? {
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
                longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
            )
            return MKCoordinateRegion(center: center, span: span)
        }() : nil

        return OverviewMapScanResult(
            candidates: candidates,
            dataRegion: region,
            totalPointCount: totalPointCount
        )
    }

    // MARK: Overlay phase — select + simplify candidates into render data

    /// Selects candidates using viewport bounding-box intersection, simplifies, and returns render data.
    /// A route intersects the viewport when its bounding box overlaps the visible region —
    /// this correctly prioritises long routes that cross the viewport edge even if their midpoint is outside.
    nonisolated static func buildOverlaysFromCandidates(
        candidates: [OverviewMapPathCandidate],
        totalPointCount: Int,
        dataRegion: MKCoordinateRegion?,
        viewportRegion: MKCoordinateRegion?
    ) -> OverviewMapRenderData {
        guard !candidates.isEmpty else {
            return OverviewMapRenderData(pathOverlays: [], region: dataRegion, totalRouteCount: 0)
        }

        let profile = OverviewMapRenderProfile.resolve(
            routeCount: candidates.count,
            totalPointCount: totalPointCount
        )
        let selected = selectCandidates(candidates, viewport: viewportRegion, profile: profile)

        var pathOverlays: [OverviewMapPathOverlay] = []
        pathOverlays.reserveCapacity(selected.count)
        for candidate in selected {
            if Task.isCancelled { break }
            if let overlay = makeOverlay(from: candidate, profile: profile) {
                pathOverlays.append(overlay)
            }
        }

        let isCapped = pathOverlays.count < candidates.count
        let isOptimized = profile.simplificationEpsilonM > 30 || profile.maxPolylinePoints < 220 || isCapped

        return OverviewMapRenderData(
            pathOverlays: pathOverlays,
            region: dataRegion,
            totalRouteCount: candidates.count,
            isOptimized: isOptimized
        )
    }

    // MARK: Combined fast path (used by tests and the legacy load path)

    /// O(N) single-pass: scans candidates then builds overlays in one call.
    nonisolated static func buildRenderDataFast(
        for dateSet: Set<String>,
        export: AppExport,
        filter: AppExportQueryFilter?
    ) -> OverviewMapRenderData {
        let scanned = scanCandidates(for: dateSet, export: export, filter: filter)
        guard !scanned.candidates.isEmpty else {
            return OverviewMapRenderData(pathOverlays: [], region: scanned.dataRegion, totalRouteCount: 0)
        }
        if Task.isCancelled {
            return OverviewMapRenderData(
                pathOverlays: [], region: scanned.dataRegion, totalRouteCount: scanned.candidates.count
            )
        }
        return buildOverlaysFromCandidates(
            candidates: scanned.candidates,
            totalPointCount: scanned.totalPointCount,
            dataRegion: scanned.dataRegion,
            viewportRegion: nil
        )
    }

    // MARK: Legacy path (used by older tests via buildRenderData)

    nonisolated static func buildRenderData(
        for dates: [String],
        content: AppSessionContent,
        filter: AppExportQueryFilter?
    ) -> OverviewMapRenderData {
        var candidates: [OverviewMapPathCandidate] = []
        var allCoords: [DayMapCoordinate] = []
        var totalPointCount = 0

        for date in dates {
            guard let mapData = content.mapData(for: date, applying: filter) else { continue }
            for overlay in mapData.pathOverlays {
                guard let candidate = makeCandidate(from: overlay) else { continue }
                candidates.append(candidate)
                totalPointCount += overlay.coordinates.count
                allCoords.append(contentsOf: overlay.coordinates)
            }
        }

        let region = computeRegion(from: allCoords)
        guard !candidates.isEmpty else {
            return OverviewMapRenderData(pathOverlays: [], region: region, totalRouteCount: 0)
        }

        let profile = OverviewMapRenderProfile.resolve(
            routeCount: candidates.count,
            totalPointCount: totalPointCount
        )
        let selected = selectCandidates(candidates, viewport: region, profile: profile)
        let pathOverlays = selected.compactMap { candidate in
            makeOverlay(from: candidate, profile: profile)
        }
        let isCapped = pathOverlays.count < candidates.count
        let isOptimized = profile.simplificationEpsilonM > 30 || profile.maxPolylinePoints < 220 || isCapped

        return OverviewMapRenderData(
            pathOverlays: pathOverlays,
            region: region,
            totalRouteCount: candidates.count,
            isOptimized: isOptimized
        )
    }

    // MARK: Private helpers

    private nonisolated static func makeCandidate(from overlay: DayMapPathOverlay) -> OverviewMapPathCandidate? {
        guard overlay.coordinates.count >= 2 else { return nil }

        let coordinates = overlay.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
        }
        guard coordinates.count >= 2 else { return nil }

        var pathMinLat = coordinates[0].latitude, pathMaxLat = coordinates[0].latitude
        var pathMinLon = coordinates[0].longitude, pathMaxLon = coordinates[0].longitude
        for coord in coordinates.dropFirst() {
            if coord.latitude < pathMinLat { pathMinLat = coord.latitude }
            if coord.latitude > pathMaxLat { pathMaxLat = coord.latitude }
            if coord.longitude < pathMinLon { pathMinLon = coord.longitude }
            if coord.longitude > pathMaxLon { pathMaxLon = coord.longitude }
        }

        let scoreBase = overlay.distanceM ?? approximateDistance(for: coordinates)
        let pointWeight = log(Double(max(overlay.coordinates.count, 2)))
        let midpointIndex = coordinates.count / 2
        var hasher = Hasher()
        hasher.combine(overlay.activityType)
        hasher.combine(overlay.coordinates.count)
        hasher.combine(overlay.distanceM ?? 0)
        hasher.combine(coordinates.first?.latitude ?? 0)
        hasher.combine(coordinates.first?.longitude ?? 0)
        hasher.combine(coordinates[midpointIndex].latitude)
        hasher.combine(coordinates[midpointIndex].longitude)
        hasher.combine(coordinates.last?.latitude ?? 0)
        hasher.combine(coordinates.last?.longitude ?? 0)

        return OverviewMapPathCandidate(
            signature: hasher.finalize(),
            fullCoordinates: coordinates,
            midpoint: coordinates[midpointIndex],
            boundsMinLat: pathMinLat,
            boundsMaxLat: pathMaxLat,
            boundsMinLon: pathMinLon,
            boundsMaxLon: pathMaxLon,
            activityType: overlay.activityType,
            score: scoreBase + pointWeight * 100
        )
    }

    /// Selects up to `overlayLimit` candidates.
    /// When `viewport` is provided, routes whose bounding box intersects the viewport are
    /// prioritised — this ensures long routes crossing the viewport edge are included
    /// even when their midpoint lies outside the visible area.
    private nonisolated static func selectCandidates(
        _ candidates: [OverviewMapPathCandidate],
        viewport: MKCoordinateRegion?,
        profile: OverviewMapRenderProfile
    ) -> [OverviewMapPathCandidate] {
        let sorted = candidates.sorted { $0.score > $1.score }
        guard sorted.count > profile.overlayLimit else { return sorted }

        if let vp = viewport {
            let inViewport = sorted.filter { boundsIntersect(vp, candidate: $0) }
            if inViewport.count >= profile.overlayLimit {
                return Array(inViewport.prefix(profile.overlayLimit))
            }
            if !inViewport.isEmpty {
                let remainder = sorted
                    .filter { !boundsIntersect(vp, candidate: $0) }
                    .prefix(profile.overlayLimit - inViewport.count)
                return inViewport + Array(remainder)
            }
        }

        return Array(sorted.prefix(profile.overlayLimit))
    }

    /// Returns true when the candidate's axis-aligned bounding box overlaps the given region.
    private nonisolated static func boundsIntersect(
        _ region: MKCoordinateRegion,
        candidate: OverviewMapPathCandidate
    ) -> Bool {
        let vpMinLat = region.center.latitude - region.span.latitudeDelta / 2
        let vpMaxLat = region.center.latitude + region.span.latitudeDelta / 2
        let vpMinLon = region.center.longitude - region.span.longitudeDelta / 2
        let vpMaxLon = region.center.longitude + region.span.longitudeDelta / 2
        return candidate.boundsMinLat <= vpMaxLat
            && candidate.boundsMaxLat >= vpMinLat
            && candidate.boundsMinLon <= vpMaxLon
            && candidate.boundsMaxLon >= vpMinLon
    }

    private nonisolated static func makeOverlay(
        from candidate: OverviewMapPathCandidate,
        profile: OverviewMapRenderProfile
    ) -> OverviewMapPathOverlay? {
        let simplified = PathSimplification.douglasPeucker(
            candidate.fullCoordinates,
            epsilon: profile.simplificationEpsilonM
        )
        let decimated = decimate(simplified, maxPoints: profile.maxPolylinePoints)
        guard decimated.count >= 2 else { return nil }
        return OverviewMapPathOverlay(coordinates: decimated, activityType: candidate.activityType)
    }

    private nonisolated static func decimate(
        _ coordinates: [CLLocationCoordinate2D],
        maxPoints: Int
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints, maxPoints >= 2 else { return coordinates }
        let step = max(1, Int(ceil(Double(coordinates.count - 1) / Double(maxPoints - 1))))
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maxPoints)
        var index = 0
        while index < coordinates.count - 1 {
            result.append(coordinates[index])
            index += step
        }
        result.append(coordinates[coordinates.count - 1])
        return result
    }

    nonisolated static func computeRegion(from coordinates: [DayMapCoordinate]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.lat, maxLat = first.lat
        var minLon = first.lon, maxLon = first.lon
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.lat)
            maxLat = max(maxLat, coordinate.lat)
            minLon = min(minLon, coordinate.lon)
            maxLon = max(maxLon, coordinate.lon)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private nonisolated static func approximateDistance(for coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { partial, pair in
            let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return partial + a.distance(from: b)
        }
    }
}

#endif
