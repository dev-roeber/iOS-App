#if canImport(SwiftUI)
import SwiftUI

/// A sheet for selecting a date range filter preset or a custom date range.
///
/// Displays all presets as a list; selecting "Custom" reveals two DatePicker controls.
/// Inline validation ensures start ≤ end and the range does not exceed 10 years.
public struct HistoryDateRangePickerSheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var filter: HistoryDateRangeFilter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: HistoryDateRangePreset
    @State private var customStart: Date
    @State private var customEnd: Date

    public init(filter: Binding<HistoryDateRangeFilter>) {
        self._filter = filter
        let f = filter.wrappedValue
        self._selectedPreset = State(initialValue: f.preset)
        self._customStart = State(initialValue: f.customStart ?? Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
        self._customEnd = State(initialValue: f.customEnd ?? Date())
    }

    private var validationResult: HistoryDateRangeValidator.ValidationResult {
        guard selectedPreset == .custom else { return .valid }
        return HistoryDateRangeValidator.validate(start: customStart, end: customEnd)
    }

    private var canApply: Bool {
        validationResult == .valid
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(HistoryDateRangePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedTitle(for: preset))
                                        .font(.body)
                                        .foregroundStyle(Color.primary)
                                    if preset != .all && preset != .custom {
                                        Text(presetSubtitle(for: preset))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(t("Date Range"))
                }

                if selectedPreset == .custom {
                    Section {
                        DatePicker(
                            t("From"),
                            selection: $customStart,
                            in: customStartRange,
                            displayedComponents: .date
                        )
                        .environment(\.locale, preferences.appLocale)

                        DatePicker(
                            t("To"),
                            selection: $customEnd,
                            in: customEndRange,
                            displayedComponents: .date
                        )
                        .environment(\.locale, preferences.appLocale)

                        if let validationMessage = validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text(t("Custom Range"))
                    }
                }
            }
            .navigationTitle(t("Filter by Date"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("Apply")) {
                        applyFilter()
                        dismiss()
                    }
                    .disabled(!canApply)
                    .accessibilityHint(Text(canApply
                        ? t("Applies the selected date range to the day list.")
                        : t("Pick a start date that is not after the end date to enable Apply.")))
                }
                if filter.isActive {
                    #if os(iOS)
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            filter.reset()
                            dismiss()
                        } label: {
                            Label(t("Clear Date Range"), systemImage: "xmark.circle")
                        }
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
                            filter.reset()
                            dismiss()
                        } label: {
                            Label(t("Clear Date Range"), systemImage: "xmark.circle")
                        }
                    }
                    #endif
                }
            }
        }
    }

    private func applyFilter() {
        switch selectedPreset {
        case .custom:
            filter = HistoryDateRangeFilter(preset: .custom, customStart: customStart, customEnd: customEnd)
        default:
            filter = HistoryDateRangeFilter(preset: selectedPreset)
        }
    }

    private var customStartRange: PartialRangeThrough<Date> {
        ...customEnd
    }

    private var customEndRange: PartialRangeFrom<Date> {
        customStart...
    }

    private var validationMessage: String? {
        switch validationResult {
        case .valid:
            return nil
        case .startAfterEnd:
            return t("Start must be before or equal to end date.")
        case .tooWide:
            return t("Range cannot exceed 10 years.")
        case .startTooFarInPast:
            return t("Start date cannot be more than 10 years in the past.")
        }
    }

    private func localizedTitle(for preset: HistoryDateRangePreset) -> String {
        switch preset {
        case .all: return t("All Days")
        case .last7Days: return t("Last 7 Days")
        case .last30Days: return t("Last 30 Days")
        case .last90Days: return t("Last 90 Days")
        case .thisYear: return t("This Year")
        case .custom: return t("Custom")
        }
    }

    private func presetSubtitle(for preset: HistoryDateRangePreset) -> String {
        guard let range = preset.computedRange() else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = preferences.appLocale
        return "\(f.string(from: range.lowerBound)) – \(f.string(from: range.upperBound))"
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
