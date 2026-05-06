import Foundation

/// Single source of truth for the App-Group suite name and UserDefaults
/// keys that are shared between the main app target (LH2GPXWrapper),
/// the AppSupport library, and the WidgetKit extension (LH2GPXWidget).
///
/// Both `WidgetDataStore` copies (the AppSupport one in this module and the
/// `wrapper/LH2GPXWidget/WidgetDataStore.swift` extension target) reference
/// these constants, so a key drift between them — which previously was an
/// audit-flagged P1 risk — becomes a compile-time error.
public enum WidgetSharedKeys {
    /// App Group suite name. Must match the entitlement on every target.
    public static let suiteName = "group.de.roeber.LH2GPXWrapper"

    /// Last-recording snapshot the home-screen widget renders.
    public static let lastRecording = "lastRecording"

    /// Compact-display preference for the Live Activity Dynamic Island.
    public static let dynamicIslandCompactDisplay = "app.preferences.dynamicIslandCompactDisplay"

    /// Weekly-aggregate stats keys.
    public static let weeklyKm = "weeklyKm"
    public static let weeklyRouteCount = "weeklyRouteCount"
    public static let weeklyStatsDate = "weeklyStatsDate"
}
