#if canImport(SwiftUI)
import SwiftUI

/// Train Q, Phase 1 — small reusable SwiftUI card for the three
/// Train-O/P info tiles (`ImportValidationSummaryPresentation`,
/// `ExportFormatGuidancePresentation`, `RouteQualitySummaryPresentation`).
///
/// **What lives here:** layout-only. All copy/strings/decisions are
/// already locked by Train-P presentation helpers; this view exists so
/// the three call-sites don't reinvent the same card markup.
///
/// **Why a struct, not an extension on `LHCard`:** the existing
/// `LHCard` is a chrome-only container — the LH design language uses
/// it everywhere, so we keep it as the chrome and layer a labelled
/// content view on top. The shape ends up small enough that no
/// snapshot test is needed.
public struct ProductInfoCard: View {

    public let title: String
    /// Optional subtitle — e.g. the import-summary date range, or
    /// `nil` to suppress the row.
    public let subtitle: String?
    /// Headline body line — required. Holds the counts line for
    /// import summaries, the primary use case for export guidance, or
    /// the level hint for route quality.
    public let headline: String
    /// Optional secondary body line — holds the export tools line,
    /// the route-quality spacing line, etc.
    public let secondary: String?
    /// Bullet rows, each pre-prefixed with `• `. Used by export
    /// guidance for the strength bullets and by import summary for
    /// the warning lines.
    public let bullets: [String]
    /// Optional final muted footnote.
    public let footnote: String?
    /// Accessibility identifier applied to the root card view.
    public let rootIdentifier: String

    public init(
        title: String,
        subtitle: String? = nil,
        headline: String,
        secondary: String? = nil,
        bullets: [String] = [],
        footnote: String? = nil,
        rootIdentifier: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headline = headline
        self.secondary = secondary
        self.bullets = bullets
        self.footnote = footnote
        self.rootIdentifier = rootIdentifier
    }

    public var body: some View {
        LHCard {
            LHSectionHeader(title)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(headline)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let secondary, !secondary.isEmpty {
                Text(secondary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bullets, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(rootIdentifier)
    }
}
#endif
