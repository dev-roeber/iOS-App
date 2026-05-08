import Foundation
#if canImport(Combine)
import Combine
#endif

/// Build-158 — UserDefaults-backed boolean toggles für den internen
/// TestFlight-Testpfad.
///
/// Hintergrund: Build 157 ist über TestFlight installierbar, aber
/// `ProcessInfo.arguments` und `ProcessInfo.environment` lassen sich auf
/// dieser Strecke nicht setzen. Tester benötigen daher einen UI-gesteuerten
/// Schalter, um den feature-flagged LocalTimelineStore-Pfad und das
/// Memory-Logging gezielt einzuschalten — ohne dass dieser Schalter
/// versehentlich in einer Release-Konfiguration default-aktiv wird.
///
/// **Datenschutz-/Scope-Pflichten:**
/// 1. Es werden ausschließlich `Bool`-Werte gespeichert.
/// 2. **Keine** Standortdaten, Dateipfade, Tokens oder Userdaten.
/// 3. UserDefaults-Keys sind explizit namespaced (`LH2GPX.…`).
/// 4. Default beider Toggles ist `false`.
/// 5. Die Settings-Klasse selbst aktiviert den Store-Pfad nicht — sie ist
///    nur eine zusätzliche Aktivierungsquelle für `LocalTimelineFeatureFlags`
///    bzw. `ImportMemoryProbe`.
public final class LocalTimelineTechnicalTestSettings: ObservableObject {

    public enum Keys {
        public static let localTimelineStoreTestModeEnabled
            = "LH2GPX.localTimelineStoreTestModeEnabled"
        public static let importMemoryLoggingEnabled
            = "LH2GPX.importMemoryLoggingEnabled"
    }

    /// Geteilte Instanz für Production-Wiring (App-Shells, Probe). Nutzt
    /// `UserDefaults.standard`. Tests injizieren immer eine eigene Instanz.
    public static let shared = LocalTimelineTechnicalTestSettings()

    private let userDefaults: UserDefaults

    @Published public var localTimelineStoreTestModeEnabled: Bool {
        didSet {
            userDefaults.set(localTimelineStoreTestModeEnabled,
                             forKey: Keys.localTimelineStoreTestModeEnabled)
        }
    }

    @Published public var importMemoryLoggingEnabled: Bool {
        didSet {
            userDefaults.set(importMemoryLoggingEnabled,
                             forKey: Keys.importMemoryLoggingEnabled)
        }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.localTimelineStoreTestModeEnabled = userDefaults.bool(
            forKey: Keys.localTimelineStoreTestModeEnabled
        )
        self.importMemoryLoggingEnabled = userDefaults.bool(
            forKey: Keys.importMemoryLoggingEnabled
        )
    }

    /// Setzt beide Toggles deterministisch (Tests / Reset-Pfad).
    public func reset() {
        localTimelineStoreTestModeEnabled = false
        importMemoryLoggingEnabled = false
    }
}
