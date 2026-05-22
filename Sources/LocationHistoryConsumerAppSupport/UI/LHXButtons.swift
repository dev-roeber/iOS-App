#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHXPrimaryActionButton

/// Primary call-to-action button. Borders, padding and minimum tap
/// target follow HIG (44×44 pt). When `isDisabled == true`, the button
/// renders disabled and exposes `disabledReason` as VoiceOver hint so
/// users know *why* an action is unavailable rather than seeing a dead
/// control.
public struct LHXPrimaryActionButton: View {
    public let title: String
    public let systemImage: String?
    public let action: () -> Void
    public let isDisabled: Bool
    public let disabledReason: String?
    public let accessibilityIdentifier: String?

    public init(
        title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        disabledReason: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.disabledReason = disabledReason
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(LH2GPXTheme.primaryBlue)
        .disabled(isDisabled)
        .accessibilityHint(isDisabled ? (disabledReason ?? "") : "")
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXSecondaryActionButton

/// Secondary action button (bordered, tonal). Same 44 pt minimum target
/// and disabled-reason behaviour as `LHXPrimaryActionButton`.
public struct LHXSecondaryActionButton: View {
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let action: () -> Void
    public let isDisabled: Bool
    public let disabledReason: String?
    public let accessibilityIdentifier: String?

    public init(
        title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isDisabled: Bool = false,
        disabledReason: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isDisabled = isDisabled
        self.disabledReason = disabledReason
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .accessibilityHint(isDisabled ? (disabledReason ?? "") : "")
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXMapOverlayControl

/// Floating map overlay button used on top of a `Map(...)` surface for
/// follow / center / fullscreen / layer-toggle controls. Renders as a
/// circular tinted button against `ultraThinMaterial`.
public struct LHXMapOverlayControl: View {
    public let systemImage: String
    public let accessibilityLabel: String
    public let isActive: Bool
    public let action: () -> Void
    public let accessibilityIdentifier: String?

    public init(
        systemImage: String,
        accessibilityLabel: String,
        isActive: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.isActive = isActive
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(isActive ? Color.white : LH2GPXTheme.primaryBlue)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isActive ? LH2GPXTheme.primaryBlue : .clear)
                )
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

#endif
