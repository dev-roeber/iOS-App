import Foundation

/// App-wide export selection: which day dates are marked for export.
///
/// Embedded in `AppSessionState` so the selection is visible across all tabs/views.
/// Cleared automatically when content changes (new import or clear).
public struct ExportSelectionState: Equatable {

    /// ISO-8601 dates ("yyyy-MM-dd") currently marked for export.
    public private(set) var selectedDates: Set<String> = []

    public init() {}

    // MARK: - Queries

    public var isEmpty: Bool { selectedDates.isEmpty }
    public var count: Int { selectedDates.count }

    public func isSelected(_ date: String) -> Bool {
        selectedDates.contains(date)
    }

    // MARK: - Mutations

    public mutating func toggle(_ date: String) {
        if selectedDates.contains(date) {
            selectedDates.remove(date)
        } else {
            selectedDates.insert(date)
        }
    }

    public mutating func selectAll(from dates: [String]) {
        for date in dates { selectedDates.insert(date) }
    }

    public mutating func clearAll() {
        selectedDates.removeAll()
    }
}
