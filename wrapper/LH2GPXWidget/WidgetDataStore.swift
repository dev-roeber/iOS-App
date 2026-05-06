#if canImport(WidgetKit) && canImport(SwiftUI)
import Foundation
import LocationHistoryConsumerAppSupport

/// Shared data between the main app and the widget via UserDefaults (App Group).
/// Falls gracefully if App Group is not configured (returns nil/empty).
///
/// This file mirrors `Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift`
/// because the WidgetKit extension target can't link the AppSupport library
/// directly. Both files now share **constants** via `WidgetSharedKeys.*`, so a
/// key drift that would silently break Live Activity reads is a compile error.
/// Method signatures intentionally stay in lockstep — keep the two files
/// behaviourally identical when modifying either.
public struct WidgetDataStore {
    static var suiteName: String { WidgetSharedKeys.suiteName }

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
        defaults.set(try? JSONEncoder().encode(recording), forKey: WidgetSharedKeys.lastRecording)
    }

    public static func loadLastRecording() -> LastRecording? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: WidgetSharedKeys.lastRecording) else { return nil }
        return try? JSONDecoder().decode(LastRecording.self, from: data)
    }

    // MARK: - Preferences sync

    /// Writes the compact-display preference so the Live Activity widget can
    /// read it back. Was missing in this copy until the audit P1-3 fix —
    /// without it, the main app's prefs-sync ran but the widget side never
    /// updated when a build only touched the extension target.
    public static func saveDynamicIslandCompactDisplay(_ display: DynamicIslandCompactDisplay) {
        UserDefaults(suiteName: suiteName)?.set(display.rawValue, forKey: WidgetSharedKeys.dynamicIslandCompactDisplay)
    }

    /// Reads the compact-display preference written by the main app. Falls back to `.distance`.
    public static func loadDynamicIslandCompactDisplay() -> DynamicIslandCompactDisplay {
        guard let raw = UserDefaults(suiteName: suiteName)?.string(forKey: WidgetSharedKeys.dynamicIslandCompactDisplay),
              let value = DynamicIslandCompactDisplay(rawValue: raw) else {
            return .distance
        }
        return value
    }

    public static func saveWeeklyStats(totalKm: Double, routeCount: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(totalKm, forKey: WidgetSharedKeys.weeklyKm)
        defaults.set(routeCount, forKey: WidgetSharedKeys.weeklyRouteCount)
        defaults.set(Date(), forKey: WidgetSharedKeys.weeklyStatsDate)
    }

    public static func loadWeeklyStats() -> (km: Double, routes: Int, date: Date?)? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        let km = defaults.double(forKey: WidgetSharedKeys.weeklyKm)
        let routes = defaults.integer(forKey: WidgetSharedKeys.weeklyRouteCount)
        let date = defaults.object(forKey: WidgetSharedKeys.weeklyStatsDate) as? Date
        guard km > 0 || routes > 0 else { return nil }
        return (km, routes, date)
    }
}
#endif
