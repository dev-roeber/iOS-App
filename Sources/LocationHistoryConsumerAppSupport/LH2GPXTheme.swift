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
                    .minimumScaleFactor(0.8)
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



// MARK: - Variant B Pro · Topographic Outdoor (Train 2026-05-25)

extension LH2GPXTheme {

    /// Design-token namespace for the *Variant B Pro · Topographic Outdoor* visual
    /// language. Sourced from `variant-b-pro.html` and documented in
    /// `docs/DESIGN_VARIANT_B_PRO_IMPLEMENTATION_2026-05-25.md`.
    ///
    /// Adoption is additive — existing `LH2GPXTheme` colors stay in place.
    /// Screens opt in by referencing `LH2GPXTheme.VariantBPro.<token>` directly.
    public enum VariantBPro {

        // MARK: Surface layers (warm dark outdoor)
        public static let bgBase  = Color(red: 10/255,  green: 8/255,  blue: 7/255)
        public static let bgShell = Color(red: 20/255,  green: 16/255, blue: 13/255)
        public static let bgWarm  = Color(red: 26/255,  green: 22/255, blue: 18/255)

        public static let elev1 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.04)
        public static let elev2 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.06)
        public static let elev3 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.09)

        public static let glassThin   = Color(red: 20/255, green: 16/255, blue: 13/255).opacity(0.62)
        public static let glassDeep   = Color(red: 10/255, green: 8/255,  blue: 7/255).opacity(0.82)

        // MARK: Hairlines
        public static let hair1 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.06)
        public static let hair2 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.10)
        public static let hair3 = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.16)
        public static let hairSpec = Color(red: 1.0, green: 237/255, blue: 213/255).opacity(0.22)

        // MARK: Text hierarchy (cream-based)
        public static let textPrimary    = Color(red: 251/255, green: 241/255, blue: 224/255)
        public static let textSecondary  = Color(red: 251/255, green: 241/255, blue: 224/255).opacity(0.66)
        public static let textTertiary   = Color(red: 251/255, green: 241/255, blue: 224/255).opacity(0.42)
        public static let textQuaternary = Color(red: 251/255, green: 241/255, blue: 224/255).opacity(0.22)

        // MARK: Brand · Terra
        public static let terra50  = Color(red: 1.0,  green: 213/255, blue: 189/255)
        public static let terra100 = Color(red: 1.0,  green: 180/255, blue: 142/255)
        public static let terra300 = Color(red: 1.0,  green: 153/255, blue: 102/255)
        public static let terra500 = Color(red: 244/255, green: 123/255, blue: 77/255)
        public static let terra700 = Color(red: 216/255, green: 95/255,  blue: 55/255)

        // MARK: Semantic accents
        public static let moss        = Color(red: 199/255, green: 250/255, blue: 96/255)
        public static let mossDark    = Color(red: 157/255, green: 209/255, blue: 58/255)
        public static let teal        = Color(red: 94/255,  green: 227/255, blue: 204/255)
        public static let azure       = Color(red: 102/255, green: 168/255, blue: 1.0)
        public static let plum        = Color(red: 201/255, green: 119/255, blue: 243/255)
        public static let recordingRed     = Color(red: 1.0,   green: 59/255,  blue: 92/255)
        public static let recordingRedDark = Color(red: 224/255, green: 34/255, blue: 62/255)
        public static let amber       = Color(red: 1.0,  green: 181/255, blue: 71/255)

        // MARK: Radii
        public static let radiusCardLarge: CGFloat  = 28
        public static let radiusCardMedium: CGFloat = 22
        public static let radiusCardSmall: CGFloat  = 16
        public static let radiusPill: CGFloat       = 999
    }
}

// MARK: - Variant B Pro · Glass surface modifier

extension View {

    /// Applies the *Variant B Pro* glass-card chrome: SwiftUI `Material` background,
    /// hairline border, specular top highlight, soft shadow. Falls back gracefully
    /// to a solid warm-dark fill on platforms / OS versions where Material is
    /// unavailable. Liquid-Glass iOS-26-specific APIs are deferred — see
    /// `docs/DESIGN_VARIANT_B_PRO_IMPLEMENTATION_2026-05-25.md` §4.
    public func variantBProGlassCard(
        cornerRadius: CGFloat = LH2GPXTheme.VariantBPro.radiusCardMedium,
        material: VariantBProGlassMaterial = .regular,
        padding: CGFloat = 16
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .padding(padding)
            .modifier(LHVariantBProGlassBackground(shape: shape, material: material))
            .overlay(
                shape.stroke(LH2GPXTheme.VariantBPro.hair2, lineWidth: 0.5)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [LH2GPXTheme.VariantBPro.hairSpec, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

private struct LHVariantBProGlassBackground<S: Shape>: ViewModifier {
    let shape: S
    let material: VariantBProGlassMaterial

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(material.swiftUIMaterial, in: shape)
                .background(LH2GPXTheme.VariantBPro.bgWarm.opacity(0.45), in: shape)
        }
    }
}

/// Glass-material level used by `variantBProGlassCard`. Maps to SwiftUI `Material`
/// thicknesses; the names align with the HTML spec (`glass-thin` / `glass` /
/// `glass-deep`).
public enum VariantBProGlassMaterial {
    case thin
    case regular
    case deep

    var swiftUIMaterial: Material {
        switch self {
        case .thin:    return .ultraThinMaterial
        case .regular: return .regularMaterial
        case .deep:    return .thickMaterial
        }
    }
}

// MARK: - Liquid Glass Direction · iOS 26 ready

extension LH2GPXTheme {
    /// Light, map-first visual language derived from the LH2GPX Liquid Glass
    /// mockups. The implementation intentionally uses stable SwiftUI Material
    /// APIs here; native iOS 26 glass symbols should stay in wrapper-only code
    /// until the project is built with the iOS 26 SDK.
    public enum LiquidGlass {
        public static let canvasTop = Color(red: 247/255, green: 250/255, blue: 254/255)
        public static let canvasBottom = Color(red: 232/255, green: 238/255, blue: 246/255)
        public static let mapLand = Color(red: 237/255, green: 243/255, blue: 232/255)
        public static let mapWater = Color(red: 216/255, green: 234/255, blue: 248/255)
        public static let mapRoad = Color.white.opacity(0.78)

        public static let trackPrimary = Color(red: 11/255, green: 87/255, blue: 208/255)
        public static let tempo = Color(red: 1.0, green: 149/255, blue: 0)
        public static let elevation = Color(red: 34/255, green: 197/255, blue: 94/255)
        public static let weather = Color(red: 38/255, green: 150/255, blue: 217/255)
        public static let recording = Color(red: 239/255, green: 68/255, blue: 68/255)

        public static let ink = Color(red: 17/255, green: 24/255, blue: 39/255)
        public static let secondaryInk = Color(red: 107/255, green: 114/255, blue: 128/255)
        public static let tertiaryInk = Color(red: 156/255, green: 163/255, blue: 175/255)
        public static let hairline = Color.black.opacity(0.07)
        public static let specular = Color.white.opacity(0.74)

        public static let cardRadius: CGFloat = 28
        public static let controlRadius: CGFloat = 22
    }
}

public struct LHLiquidGlassBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LH2GPXTheme.LiquidGlass.canvasTop,
                    LH2GPXTheme.LiquidGlass.canvasBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LiquidGlassMapLines()
                .opacity(0.72)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.70),
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LiquidGlassMapLines: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Circle()
                    .fill(LH2GPXTheme.LiquidGlass.mapWater.opacity(0.72))
                    .frame(width: size.width * 0.72, height: size.width * 0.72)
                    .offset(x: -size.width * 0.34, y: -size.height * 0.08)
                    .blur(radius: 42)

                Circle()
                    .fill(LH2GPXTheme.LiquidGlass.mapLand.opacity(0.86))
                    .frame(width: size.width * 0.92, height: size.width * 0.92)
                    .offset(x: size.width * 0.33, y: size.height * 0.12)
                    .blur(radius: 52)

                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(LH2GPXTheme.LiquidGlass.mapRoad)
                        .frame(width: size.width * 0.95, height: index.isMultiple(of: 2) ? 10 : 6)
                        .rotationEffect(.degrees(Double(index) * 18 - 42))
                        .offset(
                            x: CGFloat(index - 3) * 18,
                            y: CGFloat(index - 3) * 62
                        )
                        .blur(radius: 0.4)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

public struct LHLiquidGlassSurface<Content: View>: View {
    public let cornerRadius: CGFloat
    public let padding: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(
        cornerRadius: CGFloat = LH2GPXTheme.LiquidGlass.cardRadius,
        padding: CGFloat = 18,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content()
            .padding(padding)
            .modifier(LHLiquidGlassSurfaceBackground(shape: shape))
            .overlay(shape.stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
            .overlay(alignment: .top) {
                shape
                    .stroke(LH2GPXTheme.LiquidGlass.specular, lineWidth: 1)
                    .blur(radius: 0.2)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 14)
    }
}

private struct LHLiquidGlassSurfaceBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.white.opacity(0.34), in: shape)
        }
    }
}

public struct LHLiquidGlassHeroMark: View {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IOS 26 · LIQUID GLASS · LH2GPX")
                .font(.caption2.weight(.semibold).monospaced())
                .tracking(2.2)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.tertiaryInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
                .minimumScaleFactor(0.82)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

public struct LHLiquidGlassMetricTile: View {
    public let title: String
    public let value: String
    public let systemImage: String
    public let tint: Color

    public init(title: String, value: String, systemImage: String, tint: Color) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(LH2GPXTheme.LiquidGlass.ink)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

public struct LHLiquidGlassPrivacyPill: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Label(text, systemImage: "lock.shield.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(LH2GPXTheme.LiquidGlass.secondaryInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .modifier(LHLiquidGlassSurfaceBackground(shape: Capsule()))
            .overlay(Capsule().stroke(LH2GPXTheme.LiquidGlass.hairline, lineWidth: 0.8))
            .accessibilityLabel(text)
    }
}

#endif
