import Foundation

// MARK: - LHMapHeaderVisibility

/// Discrete visibility state for a collapsible map header.
///
/// Drives the performance invariant: map content is only placed in the
/// SwiftUI view tree when `shouldRenderMap` is true (i.e. not `.hidden`).
public enum LHMapHeaderVisibility: String, Equatable, CaseIterable, Sendable {
    case hidden
    case compact
    case expanded
    case fullscreen
}

// MARK: - LHMapHeaderState

/// Testable value type that owns all map-header transitions and derived
/// properties.  No SwiftUI dependency — safe to test on Linux.
public struct LHMapHeaderState: Equatable, Sendable {

    // MARK: Defaults

    public static let defaultCompactHeight: CGFloat  = 180
    public static let defaultExpandedHeight: CGFloat = 320

    // MARK: Stored

    public var visibility: LHMapHeaderVisibility
    public var compactHeight: CGFloat
    public var expandedHeight: CGFloat
    /// When `true`, the map cannot be fully hidden via `toggleHidden()`.
    /// Use this for screens where the map must always remain visible.
    public var isSticky: Bool

    public init(
        visibility: LHMapHeaderVisibility = .compact,
        compactHeight: CGFloat  = LHMapHeaderState.defaultCompactHeight,
        expandedHeight: CGFloat = LHMapHeaderState.defaultExpandedHeight,
        isSticky: Bool = false
    ) {
        self.visibility    = visibility
        self.compactHeight  = compactHeight
        self.expandedHeight = expandedHeight
        self.isSticky       = isSticky
    }

    // MARK: Derived / performance invariant

    /// True for every state except `.hidden`.
    /// The view layer MUST gate the entire map-content `@ViewBuilder`
    /// on this flag — never use `.hidden()` or `.opacity(0)` instead.
    public var shouldRenderMap: Bool { visibility != .hidden }

    /// Frame height to apply to the map container.
    /// Returns `nil` for `.hidden` (map not rendered) and `.fullscreen`
    /// (cover presentation fills the screen separately).
    public var mapFrameHeight: CGFloat? {
        switch visibility {
        case .hidden:     return nil
        case .compact:    return compactHeight
        case .expanded:   return expandedHeight
        case .fullscreen: return nil
        }
    }

    // MARK: Convenience predicates

    public var isHidden:     Bool { visibility == .hidden }
    public var isCompact:    Bool { visibility == .compact }
    public var isExpanded:   Bool { visibility == .expanded }
    public var isFullscreen: Bool { visibility == .fullscreen }

    // MARK: Transitions

    /// Toggles between fully hidden and compact-visible.
    /// Going from any visible state (compact or expanded) always hides the map.
    /// Going from hidden always restores compact.
    /// No-op when `isSticky == true` — sticky maps cannot be fully hidden.
    public mutating func toggleHidden() {
        guard !isSticky else { return }
        visibility = visibility == .hidden ? .compact : .hidden
    }

    /// Compact → Expanded.  No-op from any other state.
    public mutating func expand() {
        if visibility == .compact { visibility = .expanded }
    }

    /// Expanded → Compact.  No-op from any other state.
    public mutating func collapse() {
        if visibility == .expanded { visibility = .compact }
    }

    /// Expanded → Fullscreen.  No-op from any other state.
    public mutating func enterFullscreen() {
        if visibility == .expanded { visibility = .fullscreen }
    }

    /// Fullscreen → Expanded.  No-op from any other state.
    public mutating func exitFullscreen() {
        if visibility == .fullscreen { visibility = .expanded }
    }

    // MARK: Button / accessibility labels (English keys, view localises via t())

    /// Label for the primary show / hide toggle button.
    public var toggleButtonLabel: String {
        visibility == .hidden ? "Show Map" : "Collapse Map"
    }

    public let expandButtonLabel:          String = "Expand Map"
    public let collapseButtonLabel:        String = "Collapse Map"
    public let fullscreenButtonLabel:      String = "Fullscreen"
    public let closeFullscreenButtonLabel: String = "Close Map"
    public let mapPreviewLabel:            String = "Map Preview"
}

// MARK: - LHCollapsibleMapHeader (SwiftUI)

#if canImport(SwiftUI)
import SwiftUI

/// A collapsible map header that injects map content via `@ViewBuilder`.
///
/// **Performance guarantee**: when `state.visibility == .hidden` the
/// `mapContent` closure is never evaluated — the map is not in the view tree.
///
/// Usage:
/// ```swift
/// LHCollapsibleMapHeader(state: $mapState, language: preferences.appLanguage) {
///     AppOverviewTracksMapView(...)
/// }
/// ```
public struct LHCollapsibleMapHeader<MapContent: View>: View {

    @Binding var state: LHMapHeaderState
    var language: AppLanguagePreference = .english
    @ViewBuilder let mapContent: () -> MapContent

    public init(
        state: Binding<LHMapHeaderState>,
        language: AppLanguagePreference = .english,
        @ViewBuilder mapContent: @escaping () -> MapContent
    ) {
        self._state    = state
        self.language  = language
        self.mapContent = mapContent
    }

    private func t(_ key: String) -> String { language.localized(key) }

    public var body: some View {
        VStack(spacing: 0) {
            controlBar
                .background(LH2GPXTheme.card)
            if state.shouldRenderMap && !state.isFullscreen {
                mapContainer
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.visibility)
#if os(iOS) || os(visionOS)
        .fullScreenCover(isPresented: Binding(
            get: { state.isFullscreen },
            set: { if !$0 { state.exitFullscreen() } }
        )) {
            fullscreenCover
        }
#endif
    }

    // MARK: Control bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            if !state.isSticky {
                Button(action: { state.toggleHidden() }) {
                    Label(
                        t(state.toggleButtonLabel),
                        systemImage: state.isHidden ? "map" : "map.slash"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t(state.toggleButtonLabel))
            }

            Spacer()

            if state.isCompact {
                iconButton(
                    systemImage: "chevron.down",
                    label: t(state.expandButtonLabel)
                ) { state.expand() }
            }

            if state.isExpanded {
                iconButton(
                    systemImage: "chevron.up",
                    label: t(state.collapseButtonLabel)
                ) { state.collapse() }

                iconButton(
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    label: t(state.fullscreenButtonLabel)
                ) { state.enterFullscreen() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func iconButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.primaryBlue)
                .padding(8)
                .background(LH2GPXTheme.chipBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Map container

    @ViewBuilder
    private var mapContainer: some View {
        if let height = state.mapFrameHeight {
            mapContent()
                .frame(height: height)
                .clipped()
                .accessibilityLabel(t(state.mapPreviewLabel))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Fullscreen cover

#if os(iOS) || os(visionOS)
    private var fullscreenCover: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                mapContent()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                Button(action: { state.exitFullscreen() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel(t(state.closeFullscreenButtonLabel))
                .padding(20)
            }
        }
        .ignoresSafeArea()
    }
#endif
}

#endif
