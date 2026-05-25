import Foundation

/// Pure-Foundation helper that decides whether a CoreLocation altitude
/// reading is good enough to surface to the user — and, if so, how to
/// format it. Centralises the "valid vertical accuracy" rule so the
/// Live-tracking UI, GPX-export pipeline, and any future Insights /
/// Day-Detail elevation surface all agree on the same definition.
///
/// **Apple Convention:** `CLLocation.verticalAccuracy` returns a negative
/// value (typically `-1.0`) when the device cannot determine altitude
/// reliably. Only **strictly positive** values count as valid altitude
/// data. See:
/// https://developer.apple.com/documentation/corelocation/cllocation/verticalaccuracy
///
/// **What this helper does NOT do:**
/// - It never invents altitude from external DEM / elevation APIs.
/// - It never enriches imported Google Timeline history.
/// - It never logs coordinates or full readings.
public enum LocationElevationFormatter {

    /// Result of evaluating a `(altitudeM, verticalAccuracyM)` pair.
    public enum Reading: Equatable {
        /// Altitude was reported with a positive vertical accuracy.
        case available(altitudeM: Double, accuracyM: Double)
        /// Altitude is missing or its vertical accuracy is `<= 0` /
        /// non-finite (`NaN`, `±Infinity`).
        case unavailable(reason: UnavailableReason)
    }

    public enum UnavailableReason: String, Equatable {
        case missing
        case invalidAccuracy
        case nonFiniteValue
    }

    /// Resolves a `(altitudeM, verticalAccuracyM)` pair to a `Reading`.
    /// `nil` inputs map to `.unavailable(.missing)`.
    public static func reading(
        altitudeM: Double?,
        verticalAccuracyM: Double?
    ) -> Reading {
        guard let altitude = altitudeM, let accuracy = verticalAccuracyM else {
            return .unavailable(reason: .missing)
        }
        guard altitude.isFinite, accuracy.isFinite else {
            return .unavailable(reason: .nonFiniteValue)
        }
        guard accuracy > 0 else {
            return .unavailable(reason: .invalidAccuracy)
        }
        return .available(altitudeM: altitude, accuracyM: accuracy)
    }

    /// Convenience: was the altitude/verticalAccuracy pair valid enough
    /// to persist or to emit a GPX `<ele>` tag for?
    public static func isValidAltitude(
        altitudeM: Double?,
        verticalAccuracyM: Double?
    ) -> Bool {
        if case .available = reading(altitudeM: altitudeM, verticalAccuracyM: verticalAccuracyM) {
            return true
        }
        return false
    }

    /// Localised display string for a `Reading`.
    /// - `available` → `"Elevation 42 m ± 8 m"` (en) / `"Höhe 42 m ± 8 m"` (de)
    /// - `unavailable` → `"Elevation unavailable"` (en) / `"Höhe nicht verfügbar"` (de)
    ///
    /// `german` toggles between the two locales the rest of the app already
    /// uses (`AppLanguagePreference.isGerman`); pure Foundation, no Locale
    /// detection so the helper stays testable on Linux/CI without UIKit.
    public static func displayText(
        for reading: Reading,
        german: Bool = false
    ) -> String {
        let label = german ? "Höhe" : "Elevation"
        switch reading {
        case .available(let altitudeM, let accuracyM):
            let alt = Int(altitudeM.rounded())
            let acc = Int(accuracyM.rounded())
            return "\(label) \(alt) m ± \(acc) m"
        case .unavailable:
            return german ? "\(label) nicht verfügbar" : "\(label) unavailable"
        }
    }

    /// Short compact value-only string ("42 m") for grid metric cards.
    /// Returns `nil` for `.unavailable` so the caller can render its own
    /// placeholder (e.g. an em-dash).
    public static func compactAltitudeText(for reading: Reading) -> String? {
        switch reading {
        case .available(let altitudeM, _):
            return "\(Int(altitudeM.rounded())) m"
        case .unavailable:
            return nil
        }
    }

    /// Short accuracy hint ("± 8 m"). `nil` for `.unavailable`.
    public static func compactAccuracyText(for reading: Reading) -> String? {
        switch reading {
        case .available(_, let accuracyM):
            return "± \(Int(accuracyM.rounded())) m"
        case .unavailable:
            return nil
        }
    }
}
