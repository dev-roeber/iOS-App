import Foundation

/// App-wide export selection: which day dates are marked for export.
///
/// Embedded in `AppSessionState` so the selection is visible across all tabs/views.
/// Cleared automatically when content changes (new import or clear).
public struct ExportSelectionState: Equatable {

    /// ISO-8601 dates ("yyyy-MM-dd") currently marked for export.
    public private(set) var selectedDates: Set<String> = []
    /// Saved live track IDs currently marked for export.
    public private(set) var selectedRecordedTrackIDs: Set<UUID> = []
    /// Per-day route selections. Key = dayIdentifier (ISO date), value = Set of route indices.
    /// If a day has no entry here, all routes for that day are implicitly included.
    public private(set) var routeSelections: [String: Set<Int>] = [:]

    public init() {}

    // MARK: - Queries

    public var isEmpty: Bool { totalCount == 0 }
    public var count: Int { totalCount }
    public var selectedDayCount: Int { selectedDates.count }
    public var selectedRecordedTrackCount: Int { selectedRecordedTrackIDs.count }
    public var totalCount: Int { selectedDates.count + selectedRecordedTrackIDs.count }

    public func isSelected(_ date: String) -> Bool {
        selectedDates.contains(date)
    }

    public func isSelected(recordedTrackID: UUID) -> Bool {
        selectedRecordedTrackIDs.contains(recordedTrackID)
    }

    // MARK: - Mutations

    public mutating func toggle(_ date: String) {
        if selectedDates.contains(date) {
            selectedDates.remove(date)
        } else {
            selectedDates.insert(date)
        }
    }

    public mutating func toggleRecordedTrack(_ id: UUID) {
        if selectedRecordedTrackIDs.contains(id) {
            selectedRecordedTrackIDs.remove(id)
        } else {
            selectedRecordedTrackIDs.insert(id)
        }
    }

    public mutating func selectAll(from dates: [String]) {
        for date in dates { selectedDates.insert(date) }
    }

    public mutating func clearAllDays() {
        selectedDates.removeAll()
    }

    public mutating func selectAllRecordedTracks(from ids: [UUID]) {
        for id in ids { selectedRecordedTrackIDs.insert(id) }
    }

    public mutating func clearAll() {
        selectedDates.removeAll()
        selectedRecordedTrackIDs.removeAll()
        routeSelections.removeAll()
    }

    public mutating func clearRecordedTracks() {
        selectedRecordedTrackIDs.removeAll()
    }

    // MARK: - Per-route selection

    /// Toggles a specific route index for the given day.
    /// After the first explicit toggle, the day enters "partial selection" mode.
    public mutating func toggleRoute(day: String, routeIndex: Int) {
        var current = routeSelections[day] ?? []
        if current.contains(routeIndex) {
            current.remove(routeIndex)
        } else {
            current.insert(routeIndex)
        }
        routeSelections[day] = current
    }

    /// Clears per-route selection for a day, reverting to "all routes" semantics.
    public mutating func clearRouteSelection(day: String) {
        routeSelections.removeValue(forKey: day)
    }

    /// Returns true if the given route index is considered selected for the day.
    /// If no explicit selection exists for the day, all routes are considered selected.
    public func isRouteSelected(day: String, routeIndex: Int) -> Bool {
        guard let selection = routeSelections[day] else { return true }
        return selection.contains(routeIndex)
    }

    /// Returns an IndexSet of the effective selected route indices for a day.
    ///
    /// - Parameter allCount: The total number of routes available for the day.
    public func effectiveRouteIndices(day: String, allCount: Int) -> IndexSet {
        guard let selection = routeSelections[day] else {
            return IndexSet(0..<allCount)
        }
        var result = IndexSet()
        for index in 0..<allCount where selection.contains(index) {
            result.insert(index)
        }
        return result
    }

    /// Returns true if any day has explicit per-route selection active.
    public var hasExplicitRouteSelection: Bool {
        !routeSelections.isEmpty
    }

    /// Number of days with explicit per-route selection.
    public var explicitRouteSelectionCount: Int {
        routeSelections.count
    }
}
