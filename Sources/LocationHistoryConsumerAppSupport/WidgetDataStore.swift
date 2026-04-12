import Foundation

/// Shared data between the main app and the widget via UserDefaults (App Group).
/// Falls gracefully if App Group is not configured (returns nil/empty).
public struct WidgetDataStore {
    static let suiteName = "group.de.roeber.LH2GPXWrapper"

    public struct LastRecording: Codable {
        public var date: Date
        public var distanceMeters: Double
        public var durationSeconds: Double
        public var trackName: String

        public var formattedDistance: String {
            distanceMeters >= 1000
                ? String(format: "%.1f km", distanceMeters / 1000)
                : String(format: "%.0f m", distanceMeters)
        }
        public var formattedDuration: String {
            let h = Int(durationSeconds) / 3600
            let m = (Int(durationSeconds) % 3600) / 60
            return h > 0 ? "\(h)h \(m)m" : "\(m) min"
        }
    }

    public static func save(recording: LastRecording) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(try? JSONEncoder().encode(recording), forKey: "lastRecording")
    }

    public static func loadLastRecording() -> LastRecording? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "lastRecording") else { return nil }
        return try? JSONDecoder().decode(LastRecording.self, from: data)
    }

    // MARK: - Preferences sync

    private static let dynamicIslandDisplayKey = "app.preferences.dynamicIslandCompactDisplay"

    /// Writes the compact-display preference so the Live Activity widget can read it.
    public static func saveDynamicIslandCompactDisplay(_ display: DynamicIslandCompactDisplay) {
        UserDefaults(suiteName: suiteName)?.set(display.rawValue, forKey: dynamicIslandDisplayKey)
    }

    /// Reads the compact-display preference. Falls back to `.distance` if not set.
    public static func loadDynamicIslandCompactDisplay() -> DynamicIslandCompactDisplay {
        guard let raw = UserDefaults(suiteName: suiteName)?.string(forKey: dynamicIslandDisplayKey),
              let value = DynamicIslandCompactDisplay(rawValue: raw) else {
            return .distance
        }
        return value
    }

    public static func saveWeeklyStats(totalKm: Double, routeCount: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(totalKm, forKey: "weeklyKm")
        defaults.set(routeCount, forKey: "weeklyRouteCount")
        defaults.set(Date(), forKey: "weeklyStatsDate")
    }

    public static func loadWeeklyStats() -> (km: Double, routes: Int, date: Date?)? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        let km = defaults.double(forKey: "weeklyKm")
        let routes = defaults.integer(forKey: "weeklyRouteCount")
        let date = defaults.object(forKey: "weeklyStatsDate") as? Date
        guard km > 0 || routes > 0 else { return nil }
        return (km, routes, date)
    }
}
