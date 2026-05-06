import Foundation
import LocationHistoryConsumer

/// Single source of truth for live tracking status.
///
/// Consolidates authorization × awaiting × recording × accuracy into one
/// dominant state, so map overlay, hero card, banner and chips never
/// disagree on the user's current situation.
public enum LiveStatus: Equatable {
    case permissionRequired(awaiting: Bool)
    case permissionDenied
    case permissionRestricted
    case backgroundUpgradePending
    case acquiringFix
    case readyWeak(accuracyM: Double)
    case readyGood(accuracyM: Double)
    case recordingAcquiring
    case recordingWeak(accuracyM: Double)
    case recordingGood(accuracyM: Double)

    /// True when the state expresses a permission situation (banner-relevant).
    public var isPermissionState: Bool {
        switch self {
        case .permissionRequired, .permissionDenied, .permissionRestricted, .backgroundUpgradePending:
            return true
        default:
            return false
        }
    }

    /// True for states that warrant a map overlay hint instead of the live map.
    public var shouldShowMapOverlayHint: Bool {
        switch self {
        case .acquiringFix, .recordingAcquiring,
             .permissionRequired, .permissionDenied, .permissionRestricted:
            return true
        default:
            return false
        }
    }
}

public enum LiveStatusResolver {

    /// GPS accuracy threshold (meters): below = good, at/above = weak.
    /// Mirrors `LiveTrackingPresentation.gpsStatusLabel`.
    public static let weakAccuracyThresholdM: Double = 30

    /// Resolve a single dominant `LiveStatus` from the given inputs.
    ///
    /// Priority:
    ///   1. denied / restricted (terminal)
    ///   2. permissionRequired (notDetermined)
    ///   3. backgroundUpgradePending
    ///   4. acquiring (no accuracy yet) — recording vs ready variant
    ///   5. recording* (accuracy good/weak)
    ///   6. ready* (accuracy good/weak)
    public static func resolve(
        authorization: LiveLocationAuthorization,
        isAwaitingAuthorization: Bool,
        isRecording: Bool,
        needsAlwaysUpgrade: Bool,
        currentAccuracyM: Double?
    ) -> LiveStatus {
        // 1. Hard permission failures dominate everything else.
        switch authorization {
        case .denied:
            return .permissionDenied
        case .restricted:
            return .permissionRestricted
        case .notDetermined:
            return .permissionRequired(awaiting: isAwaitingAuthorization)
        case .authorizedWhenInUse, .authorizedAlways:
            break
        }

        // 2. Authorized but background upgrade still pending.
        if needsAlwaysUpgrade {
            return .backgroundUpgradePending
        }

        // 3. No fix yet → acquiring.
        guard let accuracy = currentAccuracyM, accuracy >= 0 else {
            return isRecording ? .recordingAcquiring : .acquiringFix
        }

        // 4. Have a fix — classify by accuracy + recording flag.
        let isGood = accuracy < weakAccuracyThresholdM
        if isRecording {
            return isGood ? .recordingGood(accuracyM: accuracy) : .recordingWeak(accuracyM: accuracy)
        }
        return isGood ? .readyGood(accuracyM: accuracy) : .readyWeak(accuracyM: accuracy)
    }
}
