#if canImport(SwiftUI)
import SwiftUI

// MARK: - LHPageScaffold

/// Thin, opinionated content column for standard app pages.
///
/// Standardises horizontal/vertical padding and inter-section spacing so
/// individual page implementations don't need to manage these constants
/// themselves.  Wrap in a `ScrollView` when the content can overflow.
///
/// Usage:
/// ```swift
/// ScrollView {
///     LHPageScaffold {
///         sectionA
///         sectionB
///     }
/// }
/// ```
public struct LHPageScaffold<Content: View>: View {

    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var spacing: CGFloat
    @ViewBuilder let content: () -> Content

    public init(
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat   = 14,
        spacing: CGFloat           = 18,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding   = verticalPadding
        self.spacing           = spacing
        self.content           = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - LHContextBar

/// A compact sticky banner for contextual state messages — active filters,
/// drilldown origin, export context, etc.
///
/// Uses a tinted background and an optional dismiss button.
///
/// Usage:
/// ```swift
/// if filter.isActive {
///     LHContextBar(
///         message: "Range: last 30 days",
///         systemImage: "calendar",
///         tint: .blue
///     ) { filter.reset() }
/// }
/// ```
public struct LHContextBar: View {

    let message: String
    let systemImage: String
    var tint: Color
    var onDismiss: (() -> Void)?

    public init(
        message: String,
        systemImage: String,
        tint: Color = LH2GPXTheme.primaryBlue,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message     = message
        self.systemImage = systemImage
        self.tint        = tint
        self.onDismiss   = onDismiss
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.caption)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(LH2GPXTheme.separator)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#endif
