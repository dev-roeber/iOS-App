import Foundation

/// Identifies a single imported path (route) that should be hidden from the day detail view.
///
/// The original `AppExport` is never modified; deletions are stored as an overlay in
/// `AppImportedPathMutationStore` and applied at display time.
public struct ImportedPathDeletion: Codable, Equatable {
    /// The ISO-8601 date string of the day that owns the path (e.g. `"2024-05-01"`).
    public let dayKey: String
    /// Zero-based index into `Day.paths` / `DayDetailViewState.paths` for that day.
    public let pathIndex: Int

    public init(dayKey: String, pathIndex: Int) {
        self.dayKey = dayKey
        self.pathIndex = pathIndex
    }
}

/// The full set of user-requested path mutations for an import session.
public struct ImportedPathMutationSet: Codable {
    public var deletions: [ImportedPathDeletion]

    public init(deletions: [ImportedPathDeletion] = []) {
        self.deletions = deletions
    }

    public static let empty = ImportedPathMutationSet(deletions: [])
}

public extension DayDetailViewState {
    /// Returns a copy of the receiver with paths listed in `mutations` removed.
    ///
    /// - Out-of-bounds indices and deletions for other days are silently ignored.
    /// - If no deletions match this day the receiver is returned unchanged.
    func removingDeletedPaths(for mutations: ImportedPathMutationSet) -> DayDetailViewState {
        let deletedIndices = Set(
            mutations.deletions
                .filter { $0.dayKey == date }
                .map { $0.pathIndex }
        )
        guard !deletedIndices.isEmpty else { return self }
        let filteredPaths = paths.enumerated()
            .filter { !deletedIndices.contains($0.offset) }
            .map { $0.element }
        return DayDetailViewState(
            date: date,
            visits: visits,
            activities: activities,
            paths: filteredPaths,
            totalPathPointCount: filteredPaths.reduce(0) { $0 + $1.pointCount },
            hasContent: !visits.isEmpty || !activities.isEmpty || !filteredPaths.isEmpty
        )
    }
}
