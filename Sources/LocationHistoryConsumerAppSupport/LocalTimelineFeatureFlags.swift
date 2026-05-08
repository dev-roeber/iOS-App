import Foundation

/// Phase-6 Feature-Flag-Resolver für den Store-backed AppSession-Pfad.
///
/// Liest ausschließlich `ProcessInfo.arguments` und `ProcessInfo.environment`.
/// **Kein UserDefaults**, damit Standortbezogene Konfiguration nicht in
/// Preferences landet. Default ist deaktiviert; der Store-Pfad ist
/// pre-production und darf nicht versehentlich aktiv werden.
///
/// Erkannte Aktivierungsformen:
///   * Argument: `--LH2GPX_LOCAL_TIMELINE_STORE`
///   * Argument: `LH2GPX_LOCAL_TIMELINE_STORE`
///   * Environment: `LH2GPX_LOCAL_TIMELINE_STORE=1`
///   * Environment: `LH2GPX_LOCAL_TIMELINE_STORE=true`  (case-insensitive)
public struct LocalTimelineFeatureFlags: Equatable {

    public static let storeFlagName = "LH2GPX_LOCAL_TIMELINE_STORE"

    public let isLocalTimelineStoreEnabled: Bool

    public init(isLocalTimelineStoreEnabled: Bool) {
        self.isLocalTimelineStoreEnabled = isLocalTimelineStoreEnabled
    }

    /// Resolver: nimmt Argumente + Environment getrennt entgegen, damit Tests
    /// den Resolver auf Linux deterministisch fahren können.
    public static func resolve(arguments: [String],
                               environment: [String: String]) -> LocalTimelineFeatureFlags {
        let enabled = isStoreEnabled(arguments: arguments, environment: environment)
        return LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: enabled)
    }

    /// Build-158 — Resolver mit zusätzlicher Aktivierungsquelle aus den
    /// `LocalTimelineTechnicalTestSettings` (UserDefaults-Bool, default OFF).
    /// Args/ENV bleiben primär; das Setting **aktiviert zusätzlich** und
    /// **deaktiviert nichts**. Damit lässt sich der feature-flagged Pfad
    /// auch über TestFlight einschalten, wo Args/ENV nicht setzbar sind.
    public static func resolve(arguments: [String],
                               environment: [String: String],
                               settings: LocalTimelineTechnicalTestSettings)
        -> LocalTimelineFeatureFlags
    {
        let enabled = isStoreEnabled(arguments: arguments, environment: environment)
            || settings.localTimelineStoreTestModeEnabled
        return LocalTimelineFeatureFlags(isLocalTimelineStoreEnabled: enabled)
    }

    /// Convenience: nutzt `ProcessInfo.processInfo` (ohne Settings).
    public static func resolveFromProcess() -> LocalTimelineFeatureFlags {
        let info = ProcessInfo.processInfo
        return resolve(arguments: info.arguments, environment: info.environment)
    }

    /// Convenience: nutzt `ProcessInfo.processInfo` + Settings-Singleton.
    /// Default-Argument macht das Production-Wiring kompakt; Tests können
    /// eine eigene Settings-Instanz reichen.
    public static func resolveFromProcess(
        settings: LocalTimelineTechnicalTestSettings
    ) -> LocalTimelineFeatureFlags {
        let info = ProcessInfo.processInfo
        return resolve(arguments: info.arguments,
                       environment: info.environment,
                       settings: settings)
    }

    private static func isStoreEnabled(arguments: [String],
                                       environment: [String: String]) -> Bool {
        let flag = storeFlagName
        for arg in arguments {
            if arg == "--\(flag)" || arg == flag { return true }
        }
        if let value = environment[flag] {
            return isTruthy(value)
        }
        return false
    }

    private static func isTruthy(_ raw: String) -> Bool {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch v {
        case "1", "true", "yes", "on": return true
        default: return false
        }
    }
}
