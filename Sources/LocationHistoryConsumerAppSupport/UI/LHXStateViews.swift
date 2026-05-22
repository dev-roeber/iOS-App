#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHXEmptyState

/// Standardised empty-state surface used across tabs. Consolidates the
/// ~10 inline empty-state Vstacks that currently differ in spacing,
/// icon size and call-to-action style.
///
/// Layout: vertically stacked icon → headline → body → optional primary
/// action button. Inherits LH2GPXTheme tokens; safe inside `ScrollView`
/// and inside grouped `List` rows.
public struct LHXEmptyState: View {
    public let systemImage: String
    public let title: String
    public let message: String?
    public let primaryActionTitle: String?
    public let primaryAction: (() -> Void)?
    public let accessibilityIdentifier: String?

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(LH2GPXTheme.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LH2GPXTheme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let primaryActionTitle, let primaryAction {
                Button(action: primaryAction) {
                    Text(primaryActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(LH2GPXTheme.primaryBlue)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXErrorState

/// Standardised error-state surface. Differs from `LHXEmptyState` by
/// (a) red icon tint, (b) optional retry + optional dismiss action,
/// (c) error-coloured headline accent. Use for recoverable failures
/// (import errors, upload failures, sync errors).
public struct LHXErrorState: View {
    public let systemImage: String
    public let title: String
    public let message: String?
    public let retryActionTitle: String?
    public let retryAction: (() -> Void)?
    public let dismissActionTitle: String?
    public let dismissAction: (() -> Void)?
    public let accessibilityIdentifier: String?

    public init(
        systemImage: String = "exclamationmark.triangle.fill",
        title: String,
        message: String? = nil,
        retryActionTitle: String? = nil,
        retryAction: (() -> Void)? = nil,
        dismissActionTitle: String? = nil,
        dismissAction: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.retryActionTitle = retryActionTitle
        self.retryAction = retryAction
        self.dismissActionTitle = dismissActionTitle
        self.dismissAction = dismissAction
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(LH2GPXTheme.dangerRed)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LH2GPXTheme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LH2GPXTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if let dismissActionTitle, let dismissAction {
                    Button(action: dismissAction) {
                        Text(dismissActionTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                if let retryActionTitle, let retryAction {
                    Button(action: retryAction) {
                        Text(retryActionTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LH2GPXTheme.primaryBlue)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - LHXLoadingState

/// Standardised loading-state surface. Combines a `ProgressView` with
/// an optional phase label and an optional cancel button. Used while
/// the import pipeline is reading/parsing/building, or while a sync
/// operation is in flight.
public struct LHXLoadingState: View {
    public let phaseLabel: String
    public let progress: Double?
    public let cancelActionTitle: String?
    public let cancelAction: (() -> Void)?
    public let accessibilityIdentifier: String?

    public init(
        phaseLabel: String,
        progress: Double? = nil,
        cancelActionTitle: String? = nil,
        cancelAction: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.phaseLabel = phaseLabel
        self.progress = progress
        self.cancelActionTitle = cancelActionTitle
        self.cancelAction = cancelAction
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(spacing: 14) {
            if let progress {
                ProgressView(value: max(0, min(1, progress))) {
                    Text(phaseLabel)
                        .font(.subheadline)
                        .foregroundStyle(LH2GPXTheme.textPrimary)
                }
                .tint(LH2GPXTheme.primaryBlue)
            } else {
                ProgressView {
                    Text(phaseLabel)
                        .font(.subheadline)
                        .foregroundStyle(LH2GPXTheme.textPrimary)
                }
            }
            if let cancelActionTitle, let cancelAction {
                Button(role: .cancel, action: cancelAction) {
                    Text(cancelActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - Internal modifier

internal struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#endif
