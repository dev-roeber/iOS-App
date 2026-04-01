import Foundation

/// Persists favorited day identifiers (ISO-8601 date strings) in UserDefaults.
public enum DayFavoritesStore {
    private static let key = "app.dayFavorites"

    // MARK: - Read

    /// Returns the current set of favorited day identifiers.
    public static func load(userDefaults: UserDefaults = .standard) -> Set<String> {
        guard let array = userDefaults.stringArray(forKey: key) else { return [] }
        return Set(array)
    }

    // MARK: - Write

    /// Adds a day identifier to favorites.
    public static func add(dayIdentifier: String, userDefaults: UserDefaults = .standard) {
        var current = load(userDefaults: userDefaults)
        current.insert(dayIdentifier)
        save(current, userDefaults: userDefaults)
    }

    /// Removes a day identifier from favorites.
    public static func remove(dayIdentifier: String, userDefaults: UserDefaults = .standard) {
        var current = load(userDefaults: userDefaults)
        current.remove(dayIdentifier)
        save(current, userDefaults: userDefaults)
    }

    /// Toggles a day identifier in/out of favorites. Returns the new state.
    @discardableResult
    public static func toggle(dayIdentifier: String, userDefaults: UserDefaults = .standard) -> Bool {
        if contains(dayIdentifier: dayIdentifier, userDefaults: userDefaults) {
            remove(dayIdentifier: dayIdentifier, userDefaults: userDefaults)
            return false
        } else {
            add(dayIdentifier: dayIdentifier, userDefaults: userDefaults)
            return true
        }
    }

    /// Returns true if the given day identifier is favorited.
    public static func contains(dayIdentifier: String, userDefaults: UserDefaults = .standard) -> Bool {
        load(userDefaults: userDefaults).contains(dayIdentifier)
    }

    /// Removes all favorites.
    public static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: key)
    }

    // MARK: - Private

    private static func save(_ favorites: Set<String>, userDefaults: UserDefaults) {
        userDefaults.set(Array(favorites), forKey: key)
    }
}
