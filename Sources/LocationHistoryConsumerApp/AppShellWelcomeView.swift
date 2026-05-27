#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumerAppSupport
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AppShellWelcomeView (Train F.4)
//
// Drop-in replacement for `AppShellEmptyStateView` with three new things:
//
//  1. iCloud setup hint banner — surfaces only when the device has no
//     active ubiquity identity (iCloud Drive disabled). Tappable
//     "Open Settings" button drops the user into the OS settings.
//  2. Real source badge in the recent files carousel — driven by
//     `RecentFileEntry.source` (LOCAL / iCLOUD / FILE).
//  3. `.dropDestination(for: URL.self)` on the hero card — wires
//     dragged files into the existing import pipeline via `dropAction`.
//
// The legacy `AppShellEmptyStateView` stays in `AppShellRootView.swift`
// so a one-word sed revert is enough to roll back.

struct AppShellWelcomeView: View {
    let message: AppUserMessage?
    let recentFiles: [RecentFileEntry]
    let openAction: () -> Void
    let reopenRecentAction: (RecentFileEntry) -> Void
    let removeRecentAction: (RecentFileEntry) -> Void
    let clearRecentHistoryAction: () -> Void
    let loadDemoAction: () -> Void
    let clearAction: () -> Void
    let localize: (String) -> String
    /// Optional drop closure; defaults to `openAction` so existing
    /// call-sites keep working without a fileImporter detour.
    var dropAction: ((URL) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var iCloudAvailable: Bool = WelcomeICloudProbe.isAvailable()
    @State private var selectedSource: SourceTile = .local
    @State private var isDropTargeted: Bool = false
    @Namespace private var sourceNamespace

    private enum SourceTile: String, CaseIterable, Identifiable {
        case local, icloud, demo
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            LHPageScaffold(horizontalPadding: 20, verticalPadding: 28, spacing: 18) {
                LHLiquidGlassHeroMark(
                    title: "LH2GPX",
                    subtitle: localize("Private location history → GPX, KML, CSV, KMZ")
                )
                .accessibilityIdentifier("home.title")
                .modifier(StaggeredMount(delay: 0.05, reduceMotion: reduceMotion))

                if let message, message.kind == .error {
                    AppMessageCard(message: message)
                }

                heroCard
                    .modifier(StaggeredMount(delay: 0.18, reduceMotion: reduceMotion))

                if !iCloudAvailable {
                    iCloudSetupHintBanner
                        .modifier(StaggeredMount(delay: 0.30, reduceMotion: reduceMotion))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                GoogleMapsExportHelpInlineAction(
                    titleKey: "Google Maps Export Guide",
                    accessibilityIdentifier: "home.googleHelp"
                )
                .modifier(StaggeredMount(delay: 0.40, reduceMotion: reduceMotion))

                LHLiquidGlassSurface(cornerRadius: 22, padding: 14) {
                    HomeWelcomeActionRow(
                        title: localize("Load Demo"),
                        systemImage: "testtube.2",
                        accessibilityIdentifier: "home.demo",
                        action: loadDemoAction
                    )
                }
                .modifier(StaggeredMount(delay: 0.55, reduceMotion: reduceMotion))

                if !recentFiles.isEmpty {
                    recentFilesCarousel
                        .modifier(StaggeredMount(delay: 0.62, reduceMotion: reduceMotion))
                }

                LHLiquidGlassPrivacyPill(
                    localize("Processed locally · JSON, ZIP, GPX, TCX")
                )

                if message?.kind == .error {
                    Button(localize("Clear"), action: clearAction)
                        .buttonStyle(.plain)
                        .foregroundStyle(LH2GPXTheme.primaryBlue)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: iCloudAvailable)
        .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in
            refreshICloudStatus()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshICloudStatus()
        }
        #endif
    }

    // MARK: Hero card with drop destination

    @ViewBuilder
    private var heroCard: some View {
        LHLiquidGlassSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    avatarMapIcon
                    VStack(alignment: .leading, spacing: 5) {
                        Text(localize("Import your location history"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                        Text(localize("JSON · ZIP · GPX · TCX — inside .zip too."))
                            .font(.subheadline)
                            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    }
                }

                sourceTilesRow

                primaryActionButton

                Button(action: openAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                        Text(localize("Drag & drop or pick from Files"))
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LH2GPXTheme.LiquidGlass.hairline,
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.browseFiles")
            }
        }
        .overlay(alignment: .center) {
            if isDropTargeted {
                Text(localize("Drop to import"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LH2GPXTheme.LiquidGlass.trackPrimary.opacity(0.85), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let first = urls.first else { return false }
            (dropAction ?? { _ in openAction() })(first)
            return true
        } isTargeted: { targeted in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                isDropTargeted = targeted
            }
        }
    }

    private var avatarMapIcon: some View {
        ZStack {
            Circle()
                .stroke(LH2GPXTheme.LiquidGlass.trackPrimary.opacity(0.35), lineWidth: 1.5)
                .frame(width: 52, height: 52)
                .scaleEffect(reduceMotion ? 1.0 : 1.05)
                .opacity(reduceMotion ? 1.0 : 0.7)
            Image(systemName: "map.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityHidden(true)
    }

    // MARK: Source tiles (local / iCloud / demo) — morphing on iOS 26

    @ViewBuilder
    private var sourceTilesRow: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(SourceTile.allCases) { tile in
                        sourceTile(for: tile)
                            .glassEffectID(tile.rawValue, in: sourceNamespace)
                    }
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(SourceTile.allCases) { tile in
                    sourceTile(for: tile)
                }
            }
        }
    }

    @ViewBuilder
    private func sourceTile(for tile: SourceTile) -> some View {
        let isSelected = selectedSource == tile
        let info = sourceTileInfo(tile)
        Button(action: { handleSourceTileTap(tile) }) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: info.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(info.tint)
                Text(info.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                    .lineLimit(1)
                Text(info.subtitle)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? info.tint.opacity(0.12)
                          : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? info.tint.opacity(0.6) : LH2GPXTheme.LiquidGlass.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.source.\(tile.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct SourceTileInfo {
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }

    private func sourceTileInfo(_ tile: SourceTile) -> SourceTileInfo {
        switch tile {
        case .local:
            return SourceTileInfo(
                title: localize("Local"),
                subtitle: localize("Private · on device"),
                icon: "internaldrive",
                tint: LH2GPXTheme.LiquidGlass.elevation
            )
        case .icloud:
            if iCloudAvailable {
                return SourceTileInfo(
                    title: "iCloud",
                    subtitle: localize("Drive · ready"),
                    icon: "icloud",
                    tint: LH2GPXTheme.LiquidGlass.trackPrimary
                )
            } else {
                return SourceTileInfo(
                    title: "iCloud",
                    subtitle: localize("Tap to set up"),
                    icon: "icloud.slash",
                    tint: .orange
                )
            }
        case .demo:
            return SourceTileInfo(
                title: localize("Demo"),
                subtitle: localize("Sample · for testing"),
                icon: "testtube.2",
                tint: LH2GPXTheme.LiquidGlass.secondaryInk
            )
        }
    }

    private func handleSourceTileTap(_ tile: SourceTile) {
        if tile == .icloud && !iCloudAvailable {
            openSystemSettings()
            return
        }
        selectedSource = tile
    }

    // MARK: Primary action button

    @ViewBuilder
    private var primaryActionButton: some View {
        let label: String = {
            switch selectedSource {
            case .local:  return localize("Import File")
            case .icloud: return localize("Choose from iCloud Drive")
            case .demo:   return localize("Load Demo")
            }
        }()
        let icon: String = {
            switch selectedSource {
            case .local:  return "doc.badge.plus"
            case .icloud: return "icloud.and.arrow.down"
            case .demo:   return "testtube.2"
            }
        }()
        Button {
            switch selectedSource {
            case .local, .icloud: openAction()
            case .demo:           loadDemoAction()
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .tint(LH2GPXTheme.LiquidGlass.trackPrimary)
        .accessibilityIdentifier("home.import.primary")
    }

    // MARK: iCloud setup hint banner

    @ViewBuilder
    private var iCloudSetupHintBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "icloud.slash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localize("iCloud Drive not active"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                    Text(localize("Enable iCloud Drive in Settings to import files from your iCloud."))
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(action: openSystemSettings) {
                Text(localize("Open Settings"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.orange)
            .accessibilityIdentifier("home.icloud.openSettings")
            .accessibilityHint(Text(localize("Opens Settings to enable iCloud Drive")))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.30), lineWidth: 1)
        )
        .accessibilityIdentifier("home.icloud.setupHint")
    }

    // MARK: Recent files carousel

    @ViewBuilder
    private var recentFilesCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localize("Recent files"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                Spacer()
                Button(action: clearRecentHistoryAction) {
                    Text(localize("Clear"))
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(recentFiles) { entry in
                        RecentFileChip(
                            entry: entry,
                            localize: localize,
                            onOpen: { reopenRecentAction(entry) },
                            onRemove: { removeRecentAction(entry) }
                        )
                        .accessibilityIdentifier("home.recentFiles.chip.\(entry.id.uuidString)")
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .accessibilityIdentifier("home.recentFiles.carousel")
    }

    // MARK: Helpers

    private func refreshICloudStatus() {
        let now = WelcomeICloudProbe.isAvailable()
        if now != iCloudAvailable { iCloudAvailable = now }
    }

    private func openSystemSettings() {
        #if canImport(UIKit) && os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}

// MARK: - RecentFileChip

private struct RecentFileChip: View {
    let entry: RecentFileEntry
    let localize: (String) -> String
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: badge.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(badge.tint)
                    Text(badge.label)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(badge.tint)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badge.tint.opacity(0.14), in: Capsule())

                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metaLabel)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label(localize("Remove"), systemImage: "trash")
            }
        }
    }

    private struct BadgeInfo {
        let label: String
        let icon: String
        let tint: Color
    }

    private var badge: BadgeInfo {
        switch entry.source {
        case .iCloudDrive:
            return BadgeInfo(label: "iCLOUD", icon: "icloud", tint: LH2GPXTheme.LiquidGlass.trackPrimary)
        case .local:
            return BadgeInfo(label: "LOCAL", icon: "internaldrive", tint: LH2GPXTheme.LiquidGlass.elevation)
        case .unknown:
            return BadgeInfo(label: "FILE", icon: "doc", tint: LH2GPXTheme.LiquidGlass.secondaryInk)
        }
    }

    private var metaLabel: String {
        let ext = (entry.displayName as NSString).pathExtension.uppercased()
        let extPart = ext.isEmpty ? nil : ext
        let sizePart: String? = {
            guard let bytes = entry.fileSizeBytes else { return nil }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }()
        let timePart: String = {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return f.localizedString(for: entry.lastOpenedAt, relativeTo: Date())
        }()
        return [extPart, sizePart, timePart].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: - Staggered mount modifier

private struct StaggeredMount: ViewModifier {
    let delay: Double
    let reduceMotion: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content
            } else {
                content
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 8)
                    .onAppear {
                        withAnimation(
                            .spring(response: 0.55, dampingFraction: 0.85).delay(delay)
                        ) {
                            appeared = true
                        }
                    }
            }
        }
    }
}

// MARK: - HomeWelcomeActionRow (local copy; shares look with AppShellRootView.HomeActionRow)

private struct HomeWelcomeActionRow: View {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.trackPrimary)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - iCloud probe

private enum WelcomeICloudProbe {
    static func isAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}

#endif
