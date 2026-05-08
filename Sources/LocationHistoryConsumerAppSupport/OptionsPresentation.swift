import Foundation

// MARK: - OptionsPresentation

/// Static presentation helpers for the options UI.
/// Maps model state to display text and colors — no business logic.
///
/// String-returning helpers are Linux-buildable so the test suite can cover
/// them headlessly. The Color-returning helper stays behind a SwiftUI guard
/// because `Color` is a SwiftUI type.
public enum OptionsPresentation {

    public static func uploadStatusText(sendsToServer: Bool, hasValidURL: Bool) -> String {
        guard sendsToServer else { return "Disabled" }
        guard hasValidURL else { return "Invalid URL" }
        return "Active"
    }

    public static func serverUploadPrivacyText(sendsToServer: Bool, hasValidURL: Bool) -> String {
        guard sendsToServer else { return "Disabled" }
        return hasValidURL ? "Enabled" : "Enabled (invalid URL)"
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension OptionsPresentation {
    public static func uploadStatusColor(sendsToServer: Bool, hasValidURL: Bool) -> Color {
        guard sendsToServer else { return .secondary }
        guard hasValidURL else { return LH2GPXTheme.dangerRed }
        return LH2GPXTheme.successGreen
    }
}
#endif
