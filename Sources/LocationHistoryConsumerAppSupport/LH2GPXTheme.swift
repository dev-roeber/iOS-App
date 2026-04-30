#if canImport(SwiftUI)
import SwiftUI

// MARK: - Design Tokens

/// Central namespace for LH2GPX color tokens and reusable UI building blocks.
/// Keeps visual identity in one place: true-black background, dark cards, hairline
/// borders, system blue for primary actions, mint for live tracking, semantic
/// colors for status and data categories.
public enum LH2GPXTheme {

    // MARK: Card surface
    /// Neutral card fill — matches the dark translucent card language throughout the app.
    public static let card          = Color.secondary.opacity(0.062)
    /// Slightly more prominent surface for nested / elevated content.
    public static let elevatedCard  = Color.secondary.opacity(0.10)
    /// Hairline border used on card overlays.
    public static let cardBorder    = Color.primary.opacity(0.07)
    /// Drop shadow used on the standard card chrome.
    public static let cardShadow    = Color.black.opacity(0.08)
    /// Subtle separator / divider between sections.
    public static let separator     = Color.primary.opacity(0.05)
    /// Inactive chip / pill background.
    public static let chipBackground = Color.secondary.opacity(0.08)

    // MARK: Semantic action / status colors
    /// iOS system blue — primary actions and navigation.
    public static let primaryBlue    = Color.blue
    /// Mint / teal — live recording and active tracking state.
    public static let liveMint       = Color.mint
    /// Green — ready / success / OK state.
    public static let successGreen   = Color.green
    /// Orange — warning, upload hint, route visualization.
    public static let warningOrange  = Color.orange
    /// Red — stop, error, heatmap danger zone.
    public static let dangerRed      = Color.red
    /// Yellow — favorites and pinned items.
    public static let favoriteYellow = Color.yellow
    /// Purple — insights, period stats.
    public static let insightPurple  = Color.purple
    /// Orange alias used specifically for route overlays.
    public static let routeOrange    = Color.orange
    /// Purple alias used specifically for distance metrics.
    public static let distancePurple = Color.purple

    // MARK: Text hierarchy
    public static let textPrimary   = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary  = Color.primary.opacity(0.40)
}

// MARK: - Card Chrome Modifier

extension View {
    /// Applies the standard LH2GPX card surface: 16 pt padding, neutral fill,
    /// hairline border and a subtle shadow.
    public func cardChrome() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LH2GPXTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: LH2GPXTheme.cardShadow, radius: 14, y: 5)
    }
}

// MARK: - LHSectionHeader

/// Section title with an optional subtitle line, matching the heading style
/// used in Live Tracking and Export cards.
public struct LHSectionHeader: View {
    let title: String
    var subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - LHStatusChip

/// Compact Capsule chip for recording / upload / permission state labels.
public struct LHStatusChip: View {
    let title: String
    let systemImage: String
    var color: Color

    public init(title: String, systemImage: String, color: Color = .accentColor) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - LHMetricCard

/// Left-aligned metric tile: icon + label on top, bold value below.
/// Used in 2-column grids for live-tracking stats and upload diagnostics.
public struct LHMetricCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color

    public init(icon: String, label: String, value: String, color: Color = .blue) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value), \(label)")
    }
}

// MARK: - LHCard

/// Standard dark card shell used across the redesigned start and overview
/// screens. Applies the shared LH2GPX surface and hairline border.
public struct LHCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .cardChrome()
    }
}

// MARK: - LHInsightBanner

/// Informational / guidance banner with an icon, title and body text.
/// Used for permission hints, upload guidance and assistive messages.
public struct LHInsightBanner: View {
    let title: String
    let message: String
    let systemImage: String
    var tint: Color

    public init(title: String, message: String, systemImage: String, tint: Color = .blue) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - LHFilterChip

/// Toggle-style Capsule chip for filter bars (day list, heatmap controls).
/// Shows a filled checkmark when active, the provided icon when inactive.
public struct LHFilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    public init(title: String, systemImage: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "checkmark.circle.fill" : systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor.opacity(0.12) : LH2GPXTheme.chipBackground)
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#endif
