import Foundation

/// Train R, Phase 1 — Foundation-only presentation helper that turns
/// an `ExportSelectionState`-derived count tuple into a short DE/EN
/// summary the Export tab can render above the format card.
///
/// **What goes in:** only counts — `selectedDayCount`,
/// `selectedRecordedTrackCount`, and a single boolean
/// `hasExplicitPerRouteSelection` flag. No coordinates, no dates,
/// no track IDs, no path geometry. The helper is deliberately blind
/// to identity so the privacy contract holds by construction.
public enum ExportSelectionSummaryPresentation {

    /// Plain count carrier so callers can feed either a real
    /// `ExportSelectionState` or synthetic test data without dragging
    /// the full state struct into the presentation surface.
    public struct Counts: Equatable, Sendable {
        public let selectedDayCount: Int
        public let selectedRecordedTrackCount: Int
        public let hasExplicitPerRouteSelection: Bool

        public init(selectedDayCount: Int,
                    selectedRecordedTrackCount: Int,
                    hasExplicitPerRouteSelection: Bool) {
            self.selectedDayCount = selectedDayCount
            self.selectedRecordedTrackCount = selectedRecordedTrackCount
            self.hasExplicitPerRouteSelection = hasExplicitPerRouteSelection
        }

        public var totalCount: Int { selectedDayCount + selectedRecordedTrackCount }
        public var isEmpty: Bool { totalCount == 0 }
    }

    public struct Strings: Equatable, Sendable {
        public let title: String
        public let detail: String
        /// Optional second line clarifying the selection — surfaces
        /// only when the selection spans days *and* recorded tracks,
        /// or when explicit per-route selection is active.
        public let secondaryDetail: String?

        public init(title: String, detail: String, secondaryDetail: String?) {
            self.title = title
            self.detail = detail
            self.secondaryDetail = secondaryDetail
        }
    }

    /// Returns `nil` when the selection is empty — callers must keep
    /// their existing empty-state UI instead of rendering a redundant
    /// "0 days" card.
    public static func strings(for counts: Counts, german: Bool) -> Strings? {
        guard !counts.isEmpty else { return nil }
        return Strings(
            title: title(german: german),
            detail: detailLine(counts: counts, german: german),
            secondaryDetail: secondaryLine(counts: counts, german: german)
        )
    }

    // MARK: - Components (internal for direct testing)

    internal static func title(german: Bool) -> String {
        german ? "Export-Auswahl" : "Export selection"
    }

    internal static func detailLine(counts: Counts, german: Bool) -> String {
        var parts: [String] = []
        if counts.selectedDayCount > 0 {
            parts.append(dayFragment(count: counts.selectedDayCount, german: german))
        }
        if counts.selectedRecordedTrackCount > 0 {
            parts.append(trackFragment(count: counts.selectedRecordedTrackCount, german: german))
        }
        return parts.joined(separator: " · ")
    }

    /// Only emit a secondary line when it adds information the detail
    /// line can't carry. The two cases we surface:
    /// 1. Mixed selection (days + recorded tracks) — gentle reminder.
    /// 2. Explicit per-route selection in at least one day — the user
    ///    has narrowed within a day and might forget that.
    internal static func secondaryLine(counts: Counts, german: Bool) -> String? {
        let isMixed = counts.selectedDayCount > 0 && counts.selectedRecordedTrackCount > 0
        if counts.hasExplicitPerRouteSelection {
            return german
                ? "Tagesauswahl ist auf einzelne Routen eingeschränkt."
                : "Day selection is narrowed to individual routes."
        }
        if isMixed {
            return german
                ? "Mehrere Quellen ausgewählt."
                : "Multiple sources selected."
        }
        return nil
    }

    // MARK: - Pluralisation

    private static func dayFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 Tag" : "\(count) Tage"
        }
        return count == 1 ? "1 day" : "\(count) days"
    }

    private static func trackFragment(count: Int, german: Bool) -> String {
        if german {
            return count == 1 ? "1 gespeicherter Track" : "\(count) gespeicherte Tracks"
        }
        return count == 1 ? "1 saved track" : "\(count) saved tracks"
    }
}
