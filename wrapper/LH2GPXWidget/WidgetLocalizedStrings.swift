#if canImport(WidgetKit) && canImport(SwiftUI)
import Foundation
import LocationHistoryConsumerAppSupport

/// Localized strings for the LH2GPX home widget.
///
/// Widgets run in a separate extension process, so the app's in-memory
/// `AppLanguagePreference` is mirrored into the App Group UserDefaults and read
/// from there. If that shared preference is unavailable, the widget falls back
/// to the current device locale.
enum WidgetStr {
    static var noRecording: String  { t("No recording") }
    static var lastTour: String     { t("Last Tour") }
    static var thisWeek: String     { t("This Week") }
    static var noData: String       { t("No data") }
    static var liveTrack: String    { t("Live Track") }
    static var elapsed: String      { t("elapsed", de: "vergangen") }
    static var paused: String       { t("Paused", de: "Pausiert") }
    static var sampleTrackName: String { t("Morning Loop", de: "Morgenrunde") }
    static var widgetDescription: String {
        t("Last recording and weekly stats.", de: "Letzte Aufzeichnung und Wochenstats.")
    }

    static func tourCount(_ n: Int) -> String {
        if language.isGerman {
            return n == 1 ? "Tour" : "Touren"
        } else {
            return n == 1 ? "tour" : "tours"
        }
    }

    static func pointsCount(_ n: Int) -> String {
        if language.isGerman {
            return "\(n) \(n == 1 ? "Punkt" : "Punkte")"
        }
        return "\(n) \(n == 1 ? "pt" : "pts")"
    }

    // MARK: - Private

    private static let appLanguageKey = "app.preferences.appLanguage"

    private static var language: AppLanguagePreference {
        if let rawValue = UserDefaults(suiteName: WidgetDataStore.suiteName)?.string(forKey: appLanguageKey),
           let preference = AppLanguagePreference(rawValue: rawValue) {
            return preference
        }
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return deviceLanguage.hasPrefix("de") ? .german : .english
    }

    private static func t(_ en: String, de: String? = nil) -> String {
        if let de {
            return language.isGerman ? de : en
        }
        return language.localized(en)
    }
}
#endif
