import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Declarative performance strategy for a single map surface.
///
/// `LHMapWorkspace` consumes one of these per render context (Live, DayDetail,
/// Overview, Insights, Export, Heatmap, Editor). Default profiles are exposed
/// as static factories so screens pick a profile by name and never inline
/// magic numbers. Phase A only defines the policy and its profiles; the
/// fields become load-bearing once Train 3 wires them into the actual render
/// pipeline.
///
/// See `docs/UI_UX_MAP_FIRST_LIQUID_GLASS_CONTRACT_2026-05-28.md` § 5.8.
///
/// Linux-buildable on purpose: no SwiftUI / MapKit imports. The SwiftUI-side
/// `cameraUpdateMode` mapping lives in `LHMapWorkspace` so this file stays
/// usable from Foundation-only tests.
public struct LHMapPerformancePolicy: Equatable, Sendable {

    /// Hard cap on the number of points fed into a single polyline render
    /// pass for this surface. `0` means "no cap" (heatmap-style: aggregate
    /// pipeline owns the limit, not the polyline render).
    public let renderPointCap: Int

    /// Maximum number of route overlays kept resident at once. Surfaces that
    /// page large histories (Overview, Insights) use a finite cap; modal
    /// surfaces (Editor, Export) keep the full set.
    public let routeOverlayLimit: Int

    /// When `true` the workspace filters overlays to the current viewport
    /// before rendering. Cheap polylines on small surfaces (Editor) skip
    /// this.
    public let viewportFilteringEnabled: Bool

    /// Level-of-detail strategy hint. Concrete sampling lives in the render
    /// pipeline; the policy only declares which preset to ask for.
    public let lod: LHMapLOD

    /// When `false` the workspace is free to remove the map from the view
    /// tree while the surface is hidden (e.g. behind a collapsed header).
    /// Live keeps `true` so the location authority does not lose the
    /// follow context.
    public let mapInTreeWhenHidden: Bool

    /// Camera-update cadence the workspace forwards to
    /// `Map.onMapCameraChange(frequency:)`. Most surfaces use `.onEnd` to
    /// avoid spurious rebuilds; Live uses `.continuous` so the follow
    /// camera tracks the user smoothly.
    public let cameraUpdateMode: LHMapCameraUpdateMode

    public init(
        renderPointCap: Int,
        routeOverlayLimit: Int,
        viewportFilteringEnabled: Bool,
        lod: LHMapLOD,
        mapInTreeWhenHidden: Bool,
        cameraUpdateMode: LHMapCameraUpdateMode
    ) {
        self.renderPointCap = max(0, renderPointCap)
        self.routeOverlayLimit = max(0, routeOverlayLimit)
        self.viewportFilteringEnabled = viewportFilteringEnabled
        self.lod = lod
        self.mapInTreeWhenHidden = mapInTreeWhenHidden
        self.cameraUpdateMode = cameraUpdateMode
    }
}

/// Render LOD preset, decoupled from MapKit so the policy is Foundation-only.
public enum LHMapLOD: String, Equatable, Sendable, CaseIterable {
    /// Heavy decimation; suitable for continent-scale overviews.
    case low
    /// Balanced — every-other-point sampling or similar.
    case medium
    /// Full-detail track render; only for modal surfaces or small windows.
    case high
}

/// Camera-update cadence preset, decoupled from MapKit's
/// `MapCameraUpdateFrequency` so this file is Linux-buildable.
public enum LHMapCameraUpdateMode: String, Equatable, Sendable, CaseIterable {
    case onEnd
    case continuous
}

// MARK: - Default profiles

public extension LHMapPerformancePolicy {

    /// Live tracking — needs continuous camera updates for follow mode, keeps
    /// the map alive in the view tree so the location authority stays attached.
    static let live = LHMapPerformancePolicy(
        renderPointCap: 10_000,
        routeOverlayLimit: 1,
        viewportFilteringEnabled: false,
        lod: .high,
        mapInTreeWhenHidden: true,
        cameraUpdateMode: .continuous
    )

    /// Day detail — single day, full detail, viewport filtering off (the day
    /// already fits one screen). Map can leave the tree when collapsed.
    static let dayDetail = LHMapPerformancePolicy(
        renderPointCap: 20_000,
        routeOverlayLimit: 50,
        viewportFilteringEnabled: false,
        lod: .high,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// Overview / Map tab — many tracks, viewport-filtered, decimated render.
    static let overview = LHMapPerformancePolicy(
        renderPointCap: 50_000,
        routeOverlayLimit: 500,
        viewportFilteringEnabled: true,
        lod: .low,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// Insights hero map — same render budget as Overview; camera tied to the
    /// Insights drill-down so `.onEnd` keeps things calm.
    static let insights = LHMapPerformancePolicy(
        renderPointCap: 50_000,
        routeOverlayLimit: 500,
        viewportFilteringEnabled: true,
        lod: .low,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// Export preview — modal, no viewport filtering (export must show
    /// everything that ships), capped at MapKit polyline practical limit.
    static let export = LHMapPerformancePolicy(
        renderPointCap: 500,
        routeOverlayLimit: 500,
        viewportFilteringEnabled: false,
        lod: .medium,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// Heatmap — aggregate pipeline owns the rendering budget; polyline cap
    /// is `0` because polylines are not the rendering path for this surface.
    static let heatmap = LHMapPerformancePolicy(
        renderPointCap: 0,
        routeOverlayLimit: 0,
        viewportFilteringEnabled: true,
        lod: .medium,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// Recorded-track editor — modal, single track, full detail, no
    /// viewport filtering (handles must stay reachable at every zoom).
    static let editor = LHMapPerformancePolicy(
        renderPointCap: 20_000,
        routeOverlayLimit: 1,
        viewportFilteringEnabled: false,
        lod: .high,
        mapInTreeWhenHidden: false,
        cameraUpdateMode: .onEnd
    )

    /// All default profiles in a stable order — useful for tests and for
    /// surfacing the inventory in audit docs.
    static let defaultProfiles: [LHMapPerformancePolicy] = [
        .live, .dayDetail, .overview, .insights, .export, .heatmap, .editor
    ]
}
