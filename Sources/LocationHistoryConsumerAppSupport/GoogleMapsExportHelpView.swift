#if canImport(SwiftUI)
import SwiftUI

// MARK: - Google Maps Export Help Sheet

/// Compact help sheet explaining how to export Timeline data from Google Maps on iPhone.
/// Triggered by the info button in AppSourceSummaryCard.
public struct GoogleMapsExportHelpSheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    let dismiss: () -> Void

    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label(t("Google Maps Export on iPhone"), systemImage: "location.circle")
                    .font(.headline)
                Spacer()
                Button(action: dismiss) {
                    Text(t("Done"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("Dismiss help"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(steps, id: \.number) { step in
                        stepRow(step)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    Text(t("If the direct export is unavailable, a Google Takeout export may be required depending on your account."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Steps

    private struct HelpStep {
        let number: Int
        let icon: String
        let text: String
    }

    private var steps: [HelpStep] {
        [
            HelpStep(number: 1, icon: "map",
                     text: t("Open Google Maps on your iPhone.")),
            HelpStep(number: 2, icon: "person.circle",
                     text: t("Tap your profile picture and open Settings.")),
            HelpStep(number: 3, icon: "location.slash",
                     text: t("Open \u{201C}Location & Privacy\u{201D} and select \u{201C}Export Timeline data\u{201D}.")),
            HelpStep(number: 4, icon: "arrow.down.doc",
                     text: t("Save the file to \u{201C}Files\u{201D}, then open it here in LH2GPX.")),
        ]
    }

    @ViewBuilder
    private func stepRow(_ step: HelpStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 32, height: 32)
                Text("\(step.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(step.text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t("Step")) \(step.number): \(step.text)")
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Info Button

/// Small info button that triggers the Google Maps export help sheet.
public struct GoogleMapsExportHelpButton: View {
    @EnvironmentObject private var preferences: AppPreferences
    @State private var showHelp = false

    public init() {}

    public var body: some View {
        Button {
            showHelp = true
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(Color.accentColor)
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preferences.localized("Google Maps export help"))
        .sheet(isPresented: $showHelp) {
            GoogleMapsExportHelpSheet { showHelp = false }
                .environmentObject(preferences)
        }
    }
}

#endif
