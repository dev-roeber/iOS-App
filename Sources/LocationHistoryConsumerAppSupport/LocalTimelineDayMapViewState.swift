import Foundation
import LocationHistoryConsumer

/// Phase-10A — Foundation-only Presentation-Schicht für die Store-DayMap-UI.
///
/// `LocalTimelineDayMapViewState` ist die UI-/Renderer-unabhängige Sicht auf
/// die Routen eines Tages aus dem `LocalTimelineStore`. Die Schicht nutzt
/// ausschließlich `StoreBackedMapDataProvider` und hält dabei harte Budgets
/// (Routen pro Tag, Punkte pro Route, Punkte gesamt) ein.
///
/// **Bounded-read-Garantien** (durchsetzbar im Linux-Test):
/// 1. Routenkandidaten lesen ausschließlich Path-Metadaten (kein
///    `coord_blob`-Decoding, kein `[Double]`).
/// 2. Geometrie wird **ausschließlich** für Pfade dekodiert, deren ID in
///    `selectedPathIDs` enthalten ist — und auch dann strikt bounded.
/// 3. Es entsteht **kein** `AppExport`, **keine** Tag-/Import-weite
///    `[Double]`-Materialisierung.
/// 4. Anti-Meridian-Pfade werden konservativ behandelt: Bounds werden über
///    direkte min/max-Reduktion gebildet; eine echte Splitting-Strategie
///    bleibt Phase 10B/11.
public struct LocalTimelineDayMapViewState: Equatable {

    /// Hartes Budget für Routen, Punkte pro Route und Punkte gesamt.
    public struct Budget: Equatable {
        public let maxRoutes: Int
        public let maxPointsPerRoute: Int
        public let maxTotalPoints: Int

        public init(maxRoutes: Int, maxPointsPerRoute: Int, maxTotalPoints: Int) {
            precondition(maxRoutes >= 0, "maxRoutes must be >= 0")
            precondition(maxPointsPerRoute >= 2, "maxPointsPerRoute must be >= 2")
            precondition(maxTotalPoints >= maxPointsPerRoute,
                         "maxTotalPoints must be >= maxPointsPerRoute")
            self.maxRoutes = maxRoutes
            self.maxPointsPerRoute = maxPointsPerRoute
            self.maxTotalPoints = maxTotalPoints
        }

        /// Konservativer Default: 12 Routen pro Tag, 256 Punkte pro Route,
        /// 4096 Punkte insgesamt. Die Werte liegen deutlich unter den
        /// Provider-Defaults, weil DayMap pro Sicht bewusst klein bleibt.
        public static let `default` = Budget(maxRoutes: 12,
                                             maxPointsPerRoute: 256,
                                             maxTotalPoints: 4_096)
    }

    /// Eine Route in der Tagesansicht. `decimatedPoints` ist nur belegt,
    /// wenn die `pathID` im `selectedPathIDs` der Source enthalten war und
    /// das Total-Budget noch Platz hatte.
    public struct Route: Equatable {
        public let pathID: String
        public let dayID: String
        public let mode: String?
        public let startTime: String?
        public let endTime: String?
        public let distanceM: Double
        public let pointCount: Int
        public let bbox: LocalTimelineMapBounds?
        public let decimatedPoints: [LocalTimelineMapPoint]
        public var hasGeometry: Bool { !decimatedPoints.isEmpty }
    }

    public let dayID: String
    public let detailLevel: LocalTimelineMapDetailLevel
    public let budget: Budget
    public let routes: [Route]
    public let bounds: LocalTimelineMapBounds?
    public let truncatedRoutes: Bool
    public let truncatedTotalPoints: Bool
    public let selectedPathIDs: Set<String>
    /// Phase-10B — Punktelayer-Snapshot. `nil`, wenn kein Provider verdrahtet
    /// oder `pointLayerEnabled == false` ist. Trägt nie eine vollständige
    /// Import-Geometrie und ist hart durch das übergebene `pointLayerBudget`
    /// gebunden.
    public let pointLayer: LocalTimelineMapPointLayerResponse?
    /// Tester-/Toggle-Sichtbarkeit des Punktelayers. Default in der UI ist
    /// **OFF**, damit eine bestehende Tagesansicht ohne Punkte gerendert
    /// wird; das Einschalten ist eine bewusste Entscheidung in der View
    /// (siehe `LocalTimelineDayMapView`).
    public let pointLayerEnabled: Bool

    public init(dayID: String,
                detailLevel: LocalTimelineMapDetailLevel,
                budget: Budget,
                routes: [Route],
                bounds: LocalTimelineMapBounds?,
                truncatedRoutes: Bool,
                truncatedTotalPoints: Bool,
                selectedPathIDs: Set<String>,
                pointLayer: LocalTimelineMapPointLayerResponse? = nil,
                pointLayerEnabled: Bool = false) {
        self.dayID = dayID
        self.detailLevel = detailLevel
        self.budget = budget
        self.routes = routes
        self.bounds = bounds
        self.truncatedRoutes = truncatedRoutes
        self.truncatedTotalPoints = truncatedTotalPoints
        self.selectedPathIDs = selectedPathIDs
        self.pointLayer = pointLayer
        self.pointLayerEnabled = pointLayerEnabled
    }

    public var isEmpty: Bool { routes.isEmpty && bounds == nil }
    public var totalDecodedPoints: Int { routes.reduce(0) { $0 + $1.decimatedPoints.count } }
    /// Anzahl Punktelayer-Einträge, die der View tatsächlich anzeigen würde.
    /// Liefert `0`, wenn `pointLayerEnabled == false` oder kein Snapshot
    /// vorhanden ist.
    public var visiblePointLayerCount: Int {
        guard pointLayerEnabled, let p = pointLayer else { return 0 }
        return p.entries.count
    }
}

/// Foundation-only Source für die Store-DayMap-UI. Bindet einen
/// `StoreBackedMapDataProvider` und einen optionalen Visit-Bounds-Fallback
/// an einen lade-bereiten `load(dayID:selected:)`-Closure.
public struct LocalTimelineDayMapSource {

    public typealias VisitBoundsFallback = (_ dayID: String) throws -> [LocalTimelineMapPoint]
    public typealias Loader = (_ dayID: String, _ selectedPathIDs: Set<String>) throws
        -> LocalTimelineDayMapViewState

    public let load: Loader

    public init(load: @escaping Loader) {
        self.load = load
    }

    /// Verdrahtet einen `StoreBackedMapDataProvider` als DayMap-Source.
    ///
    /// - Parameters:
    ///   - provider: Bounded-read Provider auf einen `LocalTimelineStoreReader`.
    ///   - visitsForBoundsFallback: Optionaler Closure, der Visit-Punkte
    ///     für einen Tag liefert, falls keine Path-Bbox vorhanden ist.
    ///     Default: leerer Fallback.
    ///   - budget: Hartes Routen-/Punkte-Budget. Default: `.default`.
    ///   - detailLevel: LOD für die Decimator-Stufe. Default: `.medium`.
    ///   - viewport: Räumlicher Filter für Routenkandidaten. Default: `.world`
    ///     (Tagesansicht filtert primär über `dayID`, nicht über Viewport).
    public static func make(
        provider: StoreBackedMapDataProvider,
        visitsForBoundsFallback: @escaping VisitBoundsFallback = { _ in [] },
        budget: LocalTimelineDayMapViewState.Budget = .default,
        detailLevel: LocalTimelineMapDetailLevel = .medium,
        viewport: LocalTimelineMapViewport = .world,
        pointLayerProvider: LocalTimelineMapPointLayerProvider? = nil,
        pointLayerBudget: LocalTimelineMapPerformanceBudget = .dayMap,
        pointLayerEnabled: Bool = false
    ) -> LocalTimelineDayMapSource {
        LocalTimelineDayMapSource { dayID, selected in
            try buildState(
                provider: provider,
                visitsForBoundsFallback: visitsForBoundsFallback,
                budget: budget,
                detailLevel: detailLevel,
                viewport: viewport,
                pointLayerProvider: pointLayerProvider,
                pointLayerBudget: pointLayerBudget,
                pointLayerEnabled: pointLayerEnabled,
                dayID: dayID,
                selectedPathIDs: selected
            )
        }
    }

    private static func buildState(
        provider: StoreBackedMapDataProvider,
        visitsForBoundsFallback: VisitBoundsFallback,
        budget: LocalTimelineDayMapViewState.Budget,
        detailLevel: LocalTimelineMapDetailLevel,
        viewport: LocalTimelineMapViewport,
        pointLayerProvider: LocalTimelineMapPointLayerProvider?,
        pointLayerBudget: LocalTimelineMapPerformanceBudget,
        pointLayerEnabled: Bool,
        dayID: String,
        selectedPathIDs: Set<String>
    ) throws -> LocalTimelineDayMapViewState {

        let resolvedPointLayer: LocalTimelineMapPointLayerResponse? = try {
            guard pointLayerEnabled, let plp = pointLayerProvider else { return nil }
            return try plp.dayPointCandidates(
                dayID: dayID, viewport: viewport, budget: pointLayerBudget
            )
        }()

        if budget.maxRoutes == 0 {
            return LocalTimelineDayMapViewState(
                dayID: dayID,
                detailLevel: detailLevel,
                budget: budget,
                routes: [],
                bounds: try fallbackBounds(visitsForBoundsFallback: visitsForBoundsFallback,
                                           dayID: dayID),
                truncatedRoutes: false,
                truncatedTotalPoints: false,
                selectedPathIDs: selectedPathIDs,
                pointLayer: resolvedPointLayer,
                pointLayerEnabled: pointLayerEnabled
            )
        }

        let overFetch = budget.maxRoutes &+ 1
        let candidates = try provider.dayRouteCandidates(dayID: dayID,
                                                         viewport: viewport,
                                                         limit: overFetch)
        let truncatedRoutes = candidates.count > budget.maxRoutes
        let visible = truncatedRoutes ? Array(candidates.prefix(budget.maxRoutes)) : candidates

        var routes: [LocalTimelineDayMapViewState.Route] = []
        routes.reserveCapacity(visible.count)
        var remainingTotal = budget.maxTotalPoints
        var truncatedTotalPoints = false

        for c in visible {
            let bbox: LocalTimelineMapBounds?
            if let mnLat = c.minLat, let mnLon = c.minLon,
               let mxLat = c.maxLat, let mxLon = c.maxLon {
                bbox = LocalTimelineMapBounds(minLat: mnLat, minLon: mnLon,
                                              maxLat: mxLat, maxLon: mxLon)
            } else {
                bbox = nil
            }

            var decoded: [LocalTimelineMapPoint] = []
            if selectedPathIDs.contains(c.pathID) {
                if remainingTotal <= 0 {
                    truncatedTotalPoints = true
                } else {
                    let cap = min(budget.maxPointsPerRoute, remainingTotal)
                    let geom = try provider.routeGeometry(pathID: c.pathID,
                                                          detailLevel: detailLevel,
                                                          maxPoints: cap)
                    decoded = geom.points
                    if cap < budget.maxPointsPerRoute
                        && geom.originalPointCount > geom.points.count {
                        truncatedTotalPoints = true
                    }
                    remainingTotal -= geom.points.count
                }
            }

            routes.append(LocalTimelineDayMapViewState.Route(
                pathID: c.pathID,
                dayID: c.dayID,
                mode: c.mode,
                startTime: c.startTime,
                endTime: c.endTime,
                distanceM: c.distanceM,
                pointCount: c.pointCount,
                bbox: bbox,
                decimatedPoints: decoded
            ))
        }

        let bounds: LocalTimelineMapBounds?
        if let metaBounds = boundsFromRoutes(routes) {
            bounds = metaBounds
        } else {
            bounds = try fallbackBounds(visitsForBoundsFallback: visitsForBoundsFallback,
                                        dayID: dayID)
        }

        return LocalTimelineDayMapViewState(
            dayID: dayID,
            detailLevel: detailLevel,
            budget: budget,
            routes: routes,
            bounds: bounds,
            truncatedRoutes: truncatedRoutes,
            truncatedTotalPoints: truncatedTotalPoints,
            selectedPathIDs: selectedPathIDs,
            pointLayer: resolvedPointLayer,
            pointLayerEnabled: pointLayerEnabled
        )
    }

    private static func boundsFromRoutes(
        _ routes: [LocalTimelineDayMapViewState.Route]
    ) -> LocalTimelineMapBounds? {
        var mnLat = Double.infinity
        var mnLon = Double.infinity
        var mxLat = -Double.infinity
        var mxLon = -Double.infinity
        var any = false
        for r in routes {
            guard let b = r.bbox else { continue }
            any = true
            mnLat = Swift.min(mnLat, b.minLat)
            mnLon = Swift.min(mnLon, b.minLon)
            mxLat = Swift.max(mxLat, b.maxLat)
            mxLon = Swift.max(mxLon, b.maxLon)
        }
        guard any else { return nil }
        return LocalTimelineMapBounds(minLat: mnLat, minLon: mnLon,
                                      maxLat: mxLat, maxLon: mxLon)
    }

    private static func fallbackBounds(
        visitsForBoundsFallback: VisitBoundsFallback,
        dayID: String
    ) throws -> LocalTimelineMapBounds? {
        let pts = try visitsForBoundsFallback(dayID)
        guard !pts.isEmpty else { return nil }
        var mnLat = Double.infinity
        var mnLon = Double.infinity
        var mxLat = -Double.infinity
        var mxLon = -Double.infinity
        for p in pts {
            mnLat = Swift.min(mnLat, p.latitude)
            mnLon = Swift.min(mnLon, p.longitude)
            mxLat = Swift.max(mxLat, p.latitude)
            mxLon = Swift.max(mxLon, p.longitude)
        }
        return LocalTimelineMapBounds(minLat: mnLat, minLon: mnLon,
                                      maxLat: mxLat, maxLon: mxLon)
    }
}
