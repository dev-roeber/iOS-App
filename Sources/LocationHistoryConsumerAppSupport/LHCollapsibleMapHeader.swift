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
    /// When `true`, the control bar is rendered as a semi-transparent overlay
    /// on top of the map instead of as a separate header strip above it.
    /// Use this for full-width hero map layouts where the card chrome is absent.
    var overlayControls: Bool = false
    /// Optional per-screen persistence key for the compact/expanded map size.
    /// The value intentionally stores only the discrete visibility state, not
    /// coordinates or map content.
    var persistenceKey: String?
    /// Explicit top safe-area inset for overlay control placement.
    /// Must be supplied from OUTSIDE any ignoresSafeArea context —
    /// geometry.safeAreaInsets.top returns 0 inside .safeAreaInset/.ignoresSafeArea
    /// views, so callers must capture it from a correctly-scoped GeometryReader
    /// and pass it here. Defaults to 59 (iPhone Dynamic Island baseline).
    var safeAreaTopInset: CGFloat = 59
    @ViewBuilder let mapContent: () -> MapContent

    public init(
        state: Binding<LHMapHeaderState>,
        language: AppLanguagePreference = .english,
        overlayControls: Bool = false,
        persistenceKey: String? = nil,
        safeAreaTopInset: CGFloat = 59,
        @ViewBuilder mapContent: @escaping () -> MapContent
    ) {
        self._state    = state
        self.language  = language
        self.overlayControls = overlayControls
        self.persistenceKey = persistenceKey
        self.safeAreaTopInset = safeAreaTopInset
        self.mapContent = mapContent
    }

    private func t(_ key: String) -> String { language.localized(key) }

    public var body: some View {
        Group {
            if overlayControls {
                // Hero layout: map fills full width, controls float as overlay.
                // GeometryReader without ignoresSafeArea gives us the safe-area-
                // inset frame, so the overlay buttons land below Dynamic Island.
                GeometryReader { geometry in
                    ZStack(alignment: .topTrailing) {
                        if state.shouldRenderMap && !state.isFullscreen {
                            mapContainer
                        }
                        // geometry.safeAreaInsets.top is 0 inside .safeAreaInset /
                        // .ignoresSafeArea contexts — fall back to the explicit
                        // safeAreaTopInset measured from outside that context.
                        overlayControlBar(
                            safeAreaTop: max(geometry.safeAreaInsets.top, safeAreaTopInset)
                        )
                    }
                    .frame(height: state.mapFrameHeight ?? geometry.size.height)
                }
                .frame(height: state.mapFrameHeight)
            } else {
                VStack(spacing: 0) {
                    controlBar
                        .background(LH2GPXTheme.card)
                    if state.shouldRenderMap && !state.isFullscreen {
                        mapContainer
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.visibility)
        .onAppear(perform: restorePersistedVisibility)
        .onChange(of: state.visibility) { _, newValue in
            persistVisibility(newValue)
        }
#if os(iOS)
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

    /// Hero-layout overlay slot (used when `overlayControls == true`).
    ///
    /// Historically rendered chevron-up/down + fullscreen-arrow buttons in the
    /// top-right corner. Those occluded the unified `MapLayerMenu` trigger
    /// (`slider.horizontal.3`) on every Hero-Map surface (Übersicht, Tage,
    /// Einblicke, Export), so the user only saw the layer menu on Live where
    /// no Hero-Header is in front of the inner map view. We now render an
    /// empty overlay here; `MapLayerMenu` from the inner map view sits in the
    /// same slot and is always visible. Vollbild remains reachable via
    /// `MapLayerMenu`'s toggleFullscreen action where wired by the caller.
    private func overlayControlBar(safeAreaTop: CGFloat = 0) -> some View {
        EmptyView()
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

    private var resizeHandle: some View {
        Button(action: toggleMapHeight) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(.secondary.opacity(0.65))
                    .frame(width: 44, height: 5)
                Text(t(state.isExpanded ? "Expanded map" : "Compact map"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .lgGlassPill()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.resize.handle")
        .accessibilityLabel(t("Map height"))
        .accessibilityValue(t(state.isExpanded ? "Expanded map" : "Compact map"))
        .accessibilityHint(t("Drag up to expand the map or drag down to make it compact. Double tap to switch size."))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                state.expand()
            case .decrement:
                state.collapse()
            @unknown default:
                break
            }
        }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < -28 {
                        state.expand()
                    } else if value.translation.height > 28 {
                        state.collapse()
                    }
                }
        )
    }

    // MARK: Map container

    @ViewBuilder
    private var mapContainer: some View {
        if let height = state.mapFrameHeight {
            mapContent()
                .frame(height: height)
                .clipped()
                .overlay(alignment: .bottom) {
                    if state.isCompact || state.isExpanded {
                        resizeHandle
                            .padding(.bottom, LHMapBase.attributionGuardBottomInset)
                    }
                }
                .accessibilityLabel(t(state.mapPreviewLabel))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func toggleMapHeight() {
        if state.isExpanded {
            state.collapse()
        } else if state.isCompact {
            state.expand()
        }
    }

    private func restorePersistedVisibility() {
        guard let persistenceKey,
              let rawValue = UserDefaults.standard.string(forKey: persistenceKey),
              let visibility = LHMapHeaderVisibility(rawValue: rawValue),
              visibility == .compact || visibility == .expanded
        else { return }
        state.visibility = visibility
    }

    private func persistVisibility(_ visibility: LHMapHeaderVisibility) {
        guard let persistenceKey, visibility == .compact || visibility == .expanded else { return }
        UserDefaults.standard.set(visibility.rawValue, forKey: persistenceKey)
    }

    // MARK: Fullscreen cover

#if os(iOS)
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
                        .lgGlassCircle(diameter: 56)
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
