#if canImport(Combine)
import Foundation
import Combine
import LocationHistoryConsumer

/// Persists user-requested imported-path deletions across app launches.
///
/// The store is a lightweight `ObservableObject`; views observe `currentMutations`
/// and apply the overlay at render time. The underlying `AppExport` is never modified.
public final class AppImportedPathMutationStore: ObservableObject {
    private static let userDefaultsKey = "app.importedPathMutations"
    private let userDefaults: UserDefaults

    @Published public private(set) var currentMutations: ImportedPathMutationSet

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(ImportedPathMutationSet.self, from: data) {
            currentMutations = decoded
        } else {
            currentMutations = .empty
        }
    }

    /// Adds a deletion if it is not already present.
    public func addDeletion(_ deletion: ImportedPathDeletion) {
        guard !currentMutations.deletions.contains(deletion) else { return }
        currentMutations.deletions.append(deletion)
        persist()
    }

    /// Removes all stored mutations and clears the persisted value.
    public func reset() {
        currentMutations = .empty
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(currentMutations) {
            userDefaults.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
#endif
