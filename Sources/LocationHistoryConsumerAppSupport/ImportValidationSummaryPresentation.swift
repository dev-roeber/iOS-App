import Foundation
import LocationHistoryConsumer

/// Train P, Phase 1 — Presentation layer that turns
/// `ImportValidationSummary` (Train O) into deterministic DE/EN
/// strings suitable for an "Active Source" / import-completion card.
///
/// **Privacy:** the title/subtitle/warnings/metrics strings expose
/// only counts, ranges and warning categories — never coordinates,
/// place IDs, filenames or source paths.
public enum ImportValidationSummaryPresentation {

    /// Rendered, ready-to-show strings for one summary.
    public struct Strings: Equatable, Sendable {
        public let title: String
        /// Date-range subtitle ("June 1 – June 30, 2024") or `nil` when
        /// the summary carries no dates.
        public let rangeSubtitle: String?
        /// One concise count line ("12 days · 84 routes · 350 visits").
        public let countsLine: String
        /// User-facing warning lines. Each entry is a single line of
        /// rendered copy — no coordinates, no filenames.
        public let warningLines: [String]

        public init(title: String, rangeSubtitle: String?, countsLine: String, warningLines: [String]) {
            self.title = title
            self.rangeSubtitle = rangeSubtitle
            self.countsLine = countsLine
            self.warningLines = warningLines
        }
    }

    /// Renders `Strings` for the given summary. `german == true`
    /// selects German copy; otherwise English.
    public static func strings(for summary: ImportValidationSummary, german: Bool) -> Strings {
        Strings(
            title: title(german: german),
            rangeSubtitle: rangeSubtitle(for: summary, german: german),
            countsLine: countsLine(for: summary, german: german),
            warningLines: summary.warnings.map { warningLine(for: $0, german: german) }
        )
    }

    // MARK: - Components (internal for direct testing)

    internal static func title(german: Bool) -> String {
        german ? "Importübersicht" : "Import summary"
    }

    /// Renders the date-range subtitle, or `nil` when either bound is
    /// missing. The raw `yyyy-MM-dd` keys are reformatted via the
    /// `appDateRange` formatter helper so the user sees a localised
    /// long-date span.
    internal static func rangeSubtitle(for summary: ImportValidationSummary, german: Bool) -> String? {
        guard let first = summary.firstDate, let last = summary.lastDate else { return nil }
        if first == last {
            return localisedLongDate(first, german: german)
        }
        let separator = german ? " – " : " – "
        return localisedLongDate(first, german: german) + separator + localisedLongDate(last, german: german)
    }

    internal static func countsLine(for summary: ImportValidationSummary, german: Bool) -> String {
        var parts: [String] = []
        parts.append(daysFragment(count: summary.dayCount, german: german))
        if summary.pathCount > 0 {
            parts.append(routesFragment(count: summary.pathCount, german: german))
        }
        if summary.activityCount > 0 {
            parts.append(activitiesFragment(count: summary.activityCount, german: german))
        }
        if summary.visitCount > 0 {
            parts.append(visitsFragment(count: summary.visitCount, german: german))
        }
        return parts.joined(separator: " · ")
    }

    internal static func warningLine(for warning: ImportValidationSummary.Warning, german: Bool) -> String {
        switch (warning, german) {
        case (.emptyImport, false):    return "No data — the import contained no day entries."
        case (.emptyImport, true):     return "Keine Daten – der Import enthielt keine Tageseinträge."
        case (.noGPSPoints, false):    return "No GPS points — visits, routes and activities all came in without coordinates."
        case (.noGPSPoints, true):     return "Keine GPS-Punkte – Besuche, Routen und Aktivitäten kamen ohne Koordinaten."
        case (.singleDayOnly, false):  return "Only one day in this import."
        case (.singleDayOnly, true):   return "Nur ein Tag in diesem Import."
        }
    }

    // MARK: - Count fragments

    private static func daysFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 Tag" : "\(count) Tage"
        }
        return count == 1 ? "1 day" : "\(count) days"
    }

    private static func routesFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 Route" : "\(count) Routen"
        }
        return count == 1 ? "1 route" : "\(count) routes"
    }

    private static func activitiesFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 Aktivität" : "\(count) Aktivitäten"
        }
        return count == 1 ? "1 activity" : "\(count) activities"
    }

    private static func visitsFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 Besuch" : "\(count) Besuche"
        }
        return count == 1 ? "1 visit" : "\(count) visits"
    }

    // MARK: - Date formatting

    /// Parses a `yyyy-MM-dd` key and renders it as a long-form
    /// localised date. Falls back to the raw key if parsing fails so
    /// the user always sees *something*.
    private static func localisedLongDate(_ ymd: String, german: Bool) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let date = parser.date(from: ymd) else { return ymd }

        let renderer = DateFormatter()
        renderer.locale = Locale(identifier: german ? "de_DE" : "en_US")
        renderer.timeZone = TimeZone(identifier: "UTC")
        renderer.dateStyle = .long
        renderer.timeStyle = .none
        return renderer.string(from: date)
    }
}
