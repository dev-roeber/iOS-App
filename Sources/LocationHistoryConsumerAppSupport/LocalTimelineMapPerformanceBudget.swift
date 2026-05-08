import Foundation

/// Phase-10B (Weg 3) — zentraler, adaptiver Performance-Budget-Container für
/// Store-backed Karten- und Punktelayer-Provider.
///
/// Ersetzt die starre 200-Routen-Vorstellung durch ein **detail-level-/zoom-
/// abhängiges** Budget. Der Provider darf mehr Daten verfügbar machen
/// (Pagination/Over-fetch), aber die UI/rendered data bleibt strikt bounded.
///
/// Der Typ ist Foundation-only, Equatable, deterministisch initialisierbar
/// und unterläuft keine bestehenden Caps — er aggregiert sie:
///
/// 1. `pointBudget` (entspricht `LocalTimelineMapPointBudget`) — Punktbudget
///    für Routen-Geometrie pro Pfad und Gesamt-Antwort.
/// 2. `maxVisibleRoutes` — Routen, die UI/Map gleichzeitig zeigt.
/// 3. `maxRouteCandidates` — Provider darf bis zu diesem Wert kandidieren
///    (Over-fetch / Pagination-Page-Size). Truncation wird ehrlich
///    signalisiert.
/// 4. `maxPointLayerSamples` — Hard-Cap für die Anzahl Punktelayer-Punkte
///    (Visits + Activities + sampled Route-Points), die ein einzelner
///    Provider-Request liefert.
/// 5. `maxRouteSamplePointsPerRoute` — pro Route gezogene Sample-Punkte für
///    das Punktelayer (separat vom Geometrie-Decimator).
/// 6. `maxClusters` — Cluster-Hard-Cap, falls Clustering aktiv ist.
///
/// Defaults orientieren sich an `LocalTimelineMapPointBudget.default(for:)`.
/// Werte sind bewusst konservativ: kein Pfad in der App-Pipeline soll auf
/// Mobilgeräten ein RAM-Profil aufweisen, das Jetsam riskiert.
public struct LocalTimelineMapPerformanceBudget: Equatable {

    public let detailLevel: LocalTimelineMapDetailLevel
    public let pointBudget: LocalTimelineMapPointBudget
    public let maxVisibleRoutes: Int
    public let maxRouteCandidates: Int
    public let maxPointLayerSamples: Int
    public let maxRouteSamplePointsPerRoute: Int
    public let maxClusters: Int

    public init(
        detailLevel: LocalTimelineMapDetailLevel,
        pointBudget: LocalTimelineMapPointBudget,
        maxVisibleRoutes: Int,
        maxRouteCandidates: Int,
        maxPointLayerSamples: Int,
        maxRouteSamplePointsPerRoute: Int,
        maxClusters: Int
    ) {
        precondition(maxVisibleRoutes >= 0, "maxVisibleRoutes must be >= 0")
        precondition(maxRouteCandidates >= maxVisibleRoutes,
                     "maxRouteCandidates must be >= maxVisibleRoutes")
        precondition(maxPointLayerSamples >= 0, "maxPointLayerSamples must be >= 0")
        precondition(maxRouteSamplePointsPerRoute >= 0,
                     "maxRouteSamplePointsPerRoute must be >= 0")
        precondition(maxClusters >= 0, "maxClusters must be >= 0")
        self.detailLevel = detailLevel
        self.pointBudget = pointBudget
        self.maxVisibleRoutes = maxVisibleRoutes
        self.maxRouteCandidates = maxRouteCandidates
        self.maxPointLayerSamples = maxPointLayerSamples
        self.maxRouteSamplePointsPerRoute = maxRouteSamplePointsPerRoute
        self.maxClusters = maxClusters
    }

    /// Detail-Level-/Zoom-abhängige Defaults. Werte sind hard-eingehalten von
    /// allen Store-backed Providern und View-States, die diese API nutzen.
    ///
    /// | Stufe    | maxVisibleRoutes | maxCandidates | pointLayerSamples | clusters |
    /// |----------|------------------|---------------|-------------------|----------|
    /// | overview |               24 |           256 |             1 500 |      256 |
    /// | low      |               48 |           512 |             3 000 |      512 |
    /// | medium   |               96 |         1 024 |             6 000 |    1 024 |
    /// | high     |              192 |         2 048 |            12 000 |    2 048 |
    ///
    /// Die früher harte 200-Routen-Schwelle ist damit kein Produktlimit mehr,
    /// sondern eine Render-Konsequenz aus `maxVisibleRoutes(detailLevel)` —
    /// während der Provider bis zu `maxRouteCandidates` Pfade verfügbar
    /// machen darf.
    public static func `default`(for detailLevel: LocalTimelineMapDetailLevel)
        -> LocalTimelineMapPerformanceBudget
    {
        let pb = LocalTimelineMapPointBudget.default(for: detailLevel)
        switch detailLevel {
        case .overview:
            return .init(
                detailLevel: detailLevel, pointBudget: pb,
                maxVisibleRoutes: 24, maxRouteCandidates: 256,
                maxPointLayerSamples: 1_500,
                maxRouteSamplePointsPerRoute: 8,
                maxClusters: 256
            )
        case .low:
            return .init(
                detailLevel: detailLevel, pointBudget: pb,
                maxVisibleRoutes: 48, maxRouteCandidates: 512,
                maxPointLayerSamples: 3_000,
                maxRouteSamplePointsPerRoute: 16,
                maxClusters: 512
            )
        case .medium:
            return .init(
                detailLevel: detailLevel, pointBudget: pb,
                maxVisibleRoutes: 96, maxRouteCandidates: 1_024,
                maxPointLayerSamples: 6_000,
                maxRouteSamplePointsPerRoute: 32,
                maxClusters: 1_024
            )
        case .high:
            return .init(
                detailLevel: detailLevel, pointBudget: pb,
                maxVisibleRoutes: 192, maxRouteCandidates: 2_048,
                maxPointLayerSamples: 12_000,
                maxRouteSamplePointsPerRoute: 64,
                maxClusters: 2_048
            )
        }
    }

    /// Konservatives Day-Map-Profil: bewusst kleiner als die generische
    /// Default-Stufe, weil eine Tagesansicht mit zu vielen Routen die
    /// Karte unleserlich macht und den Render-Overhead unnötig erhöht.
    public static let dayMap = LocalTimelineMapPerformanceBudget(
        detailLevel: .medium,
        pointBudget: LocalTimelineMapPointBudget(maxPointsPerRoute: 256,
                                                 maxTotalPoints: 4_096),
        maxVisibleRoutes: 12,
        maxRouteCandidates: 64,
        maxPointLayerSamples: 800,
        maxRouteSamplePointsPerRoute: 12,
        maxClusters: 256
    )
}
