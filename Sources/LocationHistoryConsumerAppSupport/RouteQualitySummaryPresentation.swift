import Foundation
import LocationHistoryConsumer

/// Train P, Phase 3 — Renders `RouteQualitySummary` (Train O) into a
/// small DE/EN UI tile for the export-preview / day-detail surface.
///
/// **Tone:** ruhig und hilfreich, kein Alarmismus. The level is shown
/// as a single short label; spacing/gap come as rounded metres so the
/// user doesn't see noisy float values.
///
/// **Privacy:** no coordinates ever appear in the strings — the helper
/// only emits the level label and rounded distances in metres.
public enum RouteQualitySummaryPresentation {

    public struct Strings: Equatable, Sendable {
        public let title: String
        public let levelLabel: String
        public let levelHint: String
        /// "Average spacing: ~12 m". `nil` when the summary has no
        /// average spacing (zero or single-point routes).
        public let spacingLine: String?
        /// "Largest gap: ~430 m". `nil` when the summary has no
        /// largest-gap value, or when level is `.good` so the gap
        /// isn't worth surfacing.
        public let largestGapLine: String?

        public init(title: String, levelLabel: String, levelHint: String,
                    spacingLine: String?, largestGapLine: String?) {
            self.title = title
            self.levelLabel = levelLabel
            self.levelHint = levelHint
            self.spacingLine = spacingLine
            self.largestGapLine = largestGapLine
        }
    }

    public static func strings(for summary: RouteQualitySummary, german: Bool) -> Strings {
        Strings(
            title: title(german: german),
            levelLabel: levelLabel(for: summary.level, german: german),
            levelHint: levelHint(for: summary.level, german: german),
            spacingLine: spacingLine(for: summary, german: german),
            largestGapLine: largestGapLine(for: summary, german: german)
        )
    }

    // MARK: - Components (internal for direct test coverage)

    internal static func title(german: Bool) -> String {
        german ? "Routenqualität" : "Route quality"
    }

    internal static func levelLabel(for level: RouteQualitySummary.Level, german: Bool) -> String {
        switch (level, german) {
        case (.empty, false):        return "No data"
        case (.empty, true):         return "Keine Daten"
        case (.sparse, false):       return "Sparse"
        case (.sparse, true):        return "Wenige Punkte"
        case (.containsGaps, false): return "Contains gaps"
        case (.containsGaps, true):  return "Mit Lücken"
        case (.good, false):         return "Good"
        case (.good, true):          return "Gut"
        }
    }

    internal static func levelHint(for level: RouteQualitySummary.Level, german: Bool) -> String {
        switch (level, german) {
        case (.empty, false):
            return "This route has no points to render."
        case (.empty, true):
            return "Diese Route enthält keine Punkte."
        case (.sparse, false):
            return "Few sample points — the route may look simplified."
        case (.sparse, true):
            return "Wenige Punkte – die Route kann vereinfacht wirken."
        case (.containsGaps, false):
            return "One or more larger gaps between samples — likely a brief signal loss."
        case (.containsGaps, true):
            return "Größere Lücken zwischen den Punkten – wahrscheinlich kurzer Signalverlust."
        case (.good, false):
            return "Evenly sampled track — looks good for export and analysis."
        case (.good, true):
            return "Gleichmäßig erfasste Strecke – gut für Export und Analyse geeignet."
        }
    }

    internal static func spacingLine(for summary: RouteQualitySummary, german: Bool) -> String? {
        guard let avg = summary.averageSpacingM, avg.isFinite, avg > 0 else { return nil }
        let rounded = roundedMetres(avg)
        if german {
            return "Punktabstand: ~\(rounded) m"
        }
        return "Average spacing: ~\(rounded) m"
    }

    /// Largest-gap line only surfaces for `.sparse` / `.containsGaps`
    /// levels — on `.good` the largest gap is roughly the average and
    /// not worth highlighting.
    internal static func largestGapLine(for summary: RouteQualitySummary, german: Bool) -> String? {
        guard let gap = summary.largestGapM, gap.isFinite, gap > 0 else { return nil }
        switch summary.level {
        case .good, .empty:
            return nil
        case .sparse, .containsGaps:
            let rounded = roundedMetres(gap)
            if german {
                return "Größte Lücke: ~\(rounded) m"
            }
            return "Largest gap: ~\(rounded) m"
        }
    }

    /// Round metres into a presentation-friendly integer. Values
    /// under 100 m round to 1 m, under 1 km to 5 m, otherwise 50 m.
    /// The user sees one stable number instead of a noisy float.
    internal static func roundedMetres(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        let absValue = abs(value)
        let step: Double
        if absValue < 100 { step = 1 }
        else if absValue < 1000 { step = 5 }
        else { step = 50 }
        return Int((absValue / step).rounded()) * Int(step)
    }
}
