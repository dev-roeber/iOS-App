#if canImport(Combine)
import Foundation
import Combine
import LocationHistoryConsumer

/// Persists user-requested imported-path deletions across app launches.
///
/// The store is a lightweight `ObservableObject`; views observe `currentMutations`
/// and apply the overlay at render time. The underlying `AppExport` is never modified.
///
/// Mutations are scoped to a source identifier (typically the import filename).
/// Calling `validateSource(_:)` on each import-change ensures that deletions from a
/// previous file are not silently applied to a new one.
public final class AppImportedPathMutationStore: ObservableObject {
    private static let userDefaultsKey = "app.importedPathMutations"
    private static let sourceIdentifierKey = "app.importedPathMutations.sourceIdentifier"
    private let userDefaults: UserDefaults

    @Published public private(set) var currentMutations: ImportedPathMutationSet
    /// `true` if the most recent `persist()` call swallowed a JSON encode
    /// failure. Surfaced as a banner-friendly flag so the UI can warn the user
    /// that their deletions may not survive an app kill. Resets to `false` on
    /// every successful `persist()`.
    @Published public private(set) var lastPersistFailed: Bool = false

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

    /// Validates that stored mutations belong to the given source identifier.
    ///
    /// Call this whenever a new import becomes active, passing the import's display
    /// name (filename) as the identifier. If the stored identifier differs from
    /// `identifier`, all mutations are cleared before the new identifier is saved.
    /// If the identifiers match, mutations are left untouched — deletions from a
    /// previous session with the same file are preserved intentionally.
    public func validateSource(_ identifier: String) {
        let stored = userDefaults.string(forKey: Self.sourceIdentifierKey)
        if stored != identifier {
            reset()
            userDefaults.set(identifier, forKey: Self.sourceIdentifierKey)
        }
    }

    /// Removes all stored mutations and clears the persisted value.
    public func reset() {
        currentMutations = .empty
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
        userDefaults.removeObject(forKey: Self.sourceIdentifierKey)
    }

    private func persist() {
        // `try? encode` previously swallowed all errors silently. A failure
        // here means the user's deletions are not persisted across launches,
        // which under memory pressure is exactly the case where it matters
        // most. Surface the failure via `lastPersistFailed` so the UI can
        // flag the divergence; reset on success.
        do {
            let data = try JSONEncoder().encode(currentMutations)
            userDefaults.set(data, forKey: Self.userDefaultsKey)
            if lastPersistFailed { lastPersistFailed = false }
        } catch {
            lastPersistFailed = true
        }
    }
}
#endif
