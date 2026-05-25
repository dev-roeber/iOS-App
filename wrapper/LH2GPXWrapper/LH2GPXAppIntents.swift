#if canImport(AppIntents)
import AppIntents

// MARK: - LH2GPX App Intents Skeleton (Train 8.3)
//
// Safe, data-free skeleton. Each intent opens the app -- nothing more.
// No location data is read, no histories are exported, no uploads are
// triggered, no iCloud sync is initiated, no live tracking is started.
// Navigation to a specific screen after open is intentionally NOT wired
// in this train (`openAppWhenRun = true` alone). The app remains free to
// add deep-link routing in a follow-up train without breaking the
// public AppIntent surface.

/// Opens the LH2GPX app. Used by Siri / Spotlight / Shortcuts as a
/// neutral entry point.
@available(iOS 17.0, *)
struct OpenLH2GPXAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open LH2GPX"
    static let description = IntentDescription(
        "Open the LH2GPX app. No data is read, exported or uploaded."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Intentionally inert: opening the app is the entire effect.
        // Screen-specific navigation is deferred to a follow-up train
        // so this skeleton can ship without architecture changes.
        return .result()
    }
}

/// Opens the LH2GPX import screen entry point. Until the app's navigation
/// layer is App-Intent-aware, this currently behaves identically to
/// `OpenLH2GPXAppIntent` — it just brings the app to the foreground.
@available(iOS 17.0, *)
struct OpenLH2GPXImportIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Import in LH2GPX"
    static let description = IntentDescription(
        "Bring LH2GPX to the foreground so you can import a location history file. The app does not auto-import anything; you choose the file yourself."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// Opens the LH2GPX settings entry point. Navigation to the exact
/// Settings sub-page is deferred to a follow-up train.
@available(iOS 17.0, *)
struct OpenLH2GPXSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open LH2GPX Settings"
    static let description = IntentDescription(
        "Bring LH2GPX to the foreground so you can review privacy, iCloud, live recording and upload settings."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - App Shortcuts surfacing

/// Surfaces the safe Open-Screen intents to Spotlight and Siri.
/// Phrases stay neutral and never mention sensitive data.
@available(iOS 17.0, *)
struct LH2GPXAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLH2GPXAppIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Open LH2GPX",
            systemImageName: "map"
        )
        AppShortcut(
            intent: OpenLH2GPXImportIntent(),
            phrases: [
                "Import in \(.applicationName)",
                "Open import in \(.applicationName)"
            ],
            shortTitle: "Open Import",
            systemImageName: "square.and.arrow.down"
        )
        AppShortcut(
            intent: OpenLH2GPXSettingsIntent(),
            phrases: [
                "Open settings in \(.applicationName)",
                "\(.applicationName) settings"
            ],
            shortTitle: "Open Settings",
            systemImageName: "slider.horizontal.3"
        )
    }
}

#endif
