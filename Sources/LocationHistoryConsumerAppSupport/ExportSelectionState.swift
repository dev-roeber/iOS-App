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
    }

    public mutating func clearRecordedTracks() {
        selectedRecordedTrackIDs.removeAll()
    }
}
