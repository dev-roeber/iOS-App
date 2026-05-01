#if canImport(SwiftUI)
import SwiftUI

// MARK: - OptionsPresentation

/// Static presentation helpers for the options UI.
/// Maps model state to display text and colors — no business logic.
public enum OptionsPresentation {

    public static func uploadStatusText(sendsToServer: Bool, hasValidURL: Bool) -> String {
        guard sendsToServer else { return "Disabled" }
        guard hasValidURL else { return "Invalid URL" }
        return "Active"
    }

    public static func uploadStatusColor(sendsToServer: Bool, hasValidURL: Bool) -> Color {
        guard sendsToServer else { return .secondary }
        guard hasValidURL else { return LH2GPXTheme.dangerRed }
        return LH2GPXTheme.successGreen
    }

    public static func serverUploadPrivacyText(sendsToServer: Bool, hasValidURL: Bool) -> String {
        guard sendsToServer else { return "Disabled" }
        return hasValidURL ? "Enabled" : "Enabled (invalid URL)"
    }
}
#endif
