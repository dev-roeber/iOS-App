#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHXStatCard

/// Thin presentational card for a single key metric. Wraps `LHMetricCard`
/// semantics with explicit `value`/`unit` slots so DynamicType-bound
/// truncation behaves predictably.
public struct LHXStatCard: View {
    public let systemImage: String
    public let label: String
    public let value: String
    public let unit: String?
    public let tint: Color
    public let accessibilityIdentifier: String?

    public init(
        systemImage: String,
        label: String,
        value: String,
        unit: String? = nil,
        tint: Color = LH2GPXTheme.primaryBlue,
        accessibilityIdentifier: String? = nil
    ) {
        self.systemImage = systemImage
        self.label = label
        self.value = value
        self.unit = unit
        self.tint = tint
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(LH2GPXTheme.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LH2GPXTheme.elevatedCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)\(unit.map { " \($0)" } ?? "")")
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXActionCard

/// Card with a primary action and an optional secondary action. Use for
/// the start-tab continue card, the live-tracking ready card, and the
/// import-first call-to-action.
public struct LHXActionCard: View {
    public let title: String
    public let message: String?
    public let systemImage: String?
    public let primaryActionTitle: String
    public let primaryAction: () -> Void
    public let secondaryActionTitle: String?
    public let secondaryAction: (() -> Void)?
    public let accessibilityIdentifier: String?

    public init(
        title: String,
        message: String? = nil,
        systemImage: String? = nil,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(LH2GPXTheme.primaryBlue)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(LH2GPXTheme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                LHXPrimaryActionButton(
                    title: primaryActionTitle,
                    action: primaryAction
                )
                if let secondaryActionTitle, let secondaryAction {
                    LHXSecondaryActionButton(
                        title: secondaryActionTitle,
                        action: secondaryAction
                    )
                }
            }
        }
        .cardChrome()
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXInfoCard

/// Read-only info card. Used for privacy hints, "what background recording
/// does" notes and other static informational surfaces. Three semantic
/// kinds (`info`, `warning`, `error`) tint the leading icon.
public struct LHXInfoCard: View {
    public enum Kind { case info, warning, error }

    public let kind: Kind
    public let title: String
    public let message: String
    public let systemImage: String?
    public let accessibilityIdentifier: String?

    public init(
        kind: Kind = .info,
        title: String,
        message: String,
        systemImage: String? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    private var iconColor: Color {
        switch kind {
        case .info:    return LH2GPXTheme.primaryBlue
        case .warning: return LH2GPXTheme.warningOrange
        case .error:   return LH2GPXTheme.dangerRed
        }
    }

    private var defaultIcon: String {
        switch kind {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage ?? defaultIcon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LH2GPXTheme.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardChrome()
        .accessibilityElement(children: .combine)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXSyncStatusCard

/// Card surface used by the Options/Settings screen to communicate iCloud
/// account state, last sync timestamp and the current opt-in state. The
/// card is purely presentational; the wiring against `CloudSyncService`
/// is the responsibility of the consuming view (planned in Train F).
public struct LHXSyncStatusCard: View {
    public enum StatusKind { case disabled, available, unavailable, signedOut, error }

    public let kind: StatusKind
    public let title: String
    public let detail: String
    public let lastSyncText: String?
    public let toggleActionTitle: String?
    public let toggleAction: (() -> Void)?
    public let accessibilityIdentifier: String?

    public init(
        kind: StatusKind,
        title: String,
        detail: String,
        lastSyncText: String? = nil,
        toggleActionTitle: String? = nil,
        toggleAction: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.lastSyncText = lastSyncText
        self.toggleActionTitle = toggleActionTitle
        self.toggleAction = toggleAction
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    private var indicatorColor: Color {
        switch kind {
        case .disabled:    return LH2GPXTheme.textTertiary
        case .available:   return LH2GPXTheme.successGreen
        case .unavailable: return LH2GPXTheme.warningOrange
        case .signedOut:   return LH2GPXTheme.warningOrange
        case .error:       return LH2GPXTheme.dangerRed
        }
    }

    private var iconName: String {
        switch kind {
        case .disabled:    return "icloud.slash"
        case .available:   return "icloud.fill"
        case .unavailable: return "icloud.slash"
        case .signedOut:   return "person.crop.circle.badge.exclamationmark"
        case .error:       return "exclamationmark.icloud.fill"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(indicatorColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LH2GPXTheme.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(LH2GPXTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let lastSyncText {
                Text(lastSyncText)
                    .font(.caption2)
                    .foregroundStyle(LH2GPXTheme.textTertiary)
            }
            if let toggleActionTitle, let toggleAction {
                Button(action: toggleAction) {
                    Text(toggleActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .cardChrome()
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

#endif
