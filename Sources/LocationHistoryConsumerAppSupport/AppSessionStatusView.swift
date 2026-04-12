#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Session Status

public struct AppSessionStatusView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let summary: AppSourceSummary
    let message: AppUserMessage?
    let isLoading: Bool
    let hasDays: Bool

    public init(summary: AppSourceSummary, message: AppUserMessage?, isLoading: Bool, hasDays: Bool) {
        self.summary = summary
        self.message = message
        self.isLoading = isLoading
        self.hasDays = hasDays
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSourceSummaryCard(summary: summary)

            if let message, message.kind == .error {
                AppMessageCard(message: message)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(t("Loading..."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !isLoading && !hasDays && summary.dayCountText != nil {
                Label(
                    t("This export contains no day entries."),
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Source Summary Card

public struct AppSourceSummaryCard: View {
    @EnvironmentObject private var preferences: AppPreferences
    let summary: AppSourceSummary
    @State private var isExpanded = false

    public init(summary: AppSourceSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t(summary.stateTitle))
                    .font(.headline)
                GoogleMapsExportHelpButton()
                Spacer()
                Text(t(summary.statusText))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            summaryRow(t(summary.sourceLabel), value: summary.sourceValue, icon: "doc")

            let hasDetails = summary.schemaVersion != nil || summary.inputFormat != nil || summary.exportedAt != nil || summary.dayCountText != nil
            if hasDetails && preferences.showsTechnicalImportDetails {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let v = summary.schemaVersion {
                            summaryRow(t("Schema"), value: v, icon: "number")
                        }
                        if let v = summary.inputFormat {
                            summaryRow(t("Format"), value: t(v), icon: "square.grid.2x2")
                        }
                        if let v = summary.exportedAt {
                            summaryRow(t("Exported"), value: v, icon: "clock")
                        }
                        if let v = summary.dayCountText {
                            summaryRow(t("Days"), value: localizeDayCountText(v), icon: "calendar")
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text(t("Technical Details"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func localizeDayCountText(_ text: String) -> String {
        guard preferences.appLanguage.isGerman,
              let count = Int(text.split(separator: " ").first ?? "") else {
            return text
        }
        return "\(count) \(count == 1 ? "Tag" : "Tage")"
    }

    @ViewBuilder
    private func summaryRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Message Card

public struct AppMessageCard: View {
    @EnvironmentObject private var preferences: AppPreferences
    let message: AppUserMessage

    public init(message: AppUserMessage) {
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                t(message.title),
                systemImage: message.kind == .error ? "exclamationmark.triangle" : "info.circle"
            )
            .font(.subheadline.weight(.semibold))
            Text(t(message.message))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        switch message.kind {
        case .info: return Color.accentColor.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        }
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
