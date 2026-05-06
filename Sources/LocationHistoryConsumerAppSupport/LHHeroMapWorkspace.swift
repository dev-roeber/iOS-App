#if canImport(SwiftUI)
import SwiftUI

// MARK: - Top safe-area helper

/// Real device top safe-area inset measured outside any
/// `safeAreaInset` / `ignoresSafeArea` context.
///
/// Inside such contexts SwiftUI's `geometry.safeAreaInsets.top`
/// returns `0`, so views that need to position overlay controls
/// (e.g. map controls drawn behind Dynamic Island / status bar)
/// must read the inset from UIKit directly.
///
/// Falls back to `59` (iPhone Dynamic Island baseline) when no
/// key window is available.
@MainActor
public func lhDeviceTopSafeInset() -> CGFloat {
    #if os(iOS)
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .safeAreaInsets.top ?? 59
    #else
    0
    #endif
}

// MARK: - Hero-Map Workspace constants

/// Shared layout constants for the cross-app Hero-Map pattern
/// (Days / Overview / Day Detail / Live).
///
/// All map-bearing primary screens use these values so the controls
/// land at consistent positions on every device. Changing a constant
/// here updates every screen at once.
public enum LHHeroMapLayout {

    /// Map height in `.compact` visibility — large enough to feel
    /// like a hero, small enough to leave room for content below.
    public static let compactHeight: CGFloat = 460

    /// Map height in `.expanded` visibility.
    public static let expandedHeight: CGFloat = 560

    /// Vertical offset for the topTrailing map control stack
    /// (Globe / Fit-to-data / Fullscreen) so it sits cleanly BELOW
    /// the `LHCollapsibleMapHeader` chevron-button.
    ///
    /// The chevron sits at `safeAreaTop + 80` and is ~44 pt tall;
    /// `+130` clears it on every iPhone size.
    public static let mapControlTopOffset: CGFloat = 130
}
#endif
