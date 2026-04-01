#if canImport(SwiftUI)
import SwiftUI

struct AppHistoryDateRangeControl: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding private var filter: HistoryDateRangeFilter
    @State private var isShowingCustomRangeSheet = false
    @State private var draftStart = AppHistoryDateRangeControl.defaultStartDate
    @State private var draftEnd = Date()

    let showsExportHint: Bool

    init(
        filter: Binding<HistoryDateRangeFilter>,
        showsExportHint: Bool = false
    ) {
        self._filter = filter
        self.showsExportHint = showsExportHint
    }

    private static var defaultStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    }

    private var customValidation: HistoryDateRangeValidator.ValidationResult {
        HistoryDateRangeValidator.validate(start: normalizedStartDate, end: normalizedEndDate)
    }

    private var normalizedStartDate: Date {
        Calendar.current.startOfDay(for: draftStart)
    }

    private var normalizedEndDate: Date {
        let startOfDay = Calendar.current.startOfDay(for: draftEnd)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? draftEnd
    }

    private var effectiveDateRangeText: String {
        guard let range = filter.effectiveRange else {
            return t("Showing the full imported time span.")
        }
        return "\(displayDate(range.lowerBound)) – \(displayDate(range.upperBound))"
    }

    private var activeRangeTitle: String {
        switch filter.preset {
        case .all:
            return t("All Time")
        case .custom:
            return t("Custom Range")
        default:
            return t(filter.preset.title)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("Time Range"), systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                    Text(activeRangeTitle)
                        .font(.subheadline.weight(.medium))
                    Text(effectiveDateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if filter.isActive {
                    Button(t("Reset to All Time")) {
                        filter.reset()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoryDateRangePreset.allCases) { preset in
                        Button {
                            handlePresetSelection(preset)
                        } label: {
                            Text(t(preset.title))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(filter.preset == preset ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                                .foregroundStyle(filter.preset == preset ? Color.accentColor : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if showsExportHint {
                Label(
                    t("Export always uses the active time range before any local export filters."),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $isShowingCustomRangeSheet) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker(
                            t("Start Date"),
                            selection: $draftStart,
                            displayedComponents: [.date]
                        )

                        DatePicker(
                            t("End Date"),
                            selection: $draftEnd,
                            displayedComponents: [.date]
                        )
                    } header: {
                        Text(t("Custom Range"))
                    } footer: {
                        Text(validationMessage ?? t("Select a custom date window."))
                    }
                }
                .navigationTitle(t("Custom Range"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(t("Cancel")) {
                            syncDraftDatesFromFilter()
                            isShowingCustomRangeSheet = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(t("Apply Range")) {
                            filter = HistoryDateRangeFilter(
                                preset: .custom,
                                customStart: normalizedStartDate,
                                customEnd: normalizedEndDate
                            )
                            isShowingCustomRangeSheet = false
                        }
                        .disabled(customValidation != .valid)
                    }
                }
            }
        }
        .onAppear {
            syncDraftDatesFromFilter()
        }
    }

    private var validationMessage: String? {
        switch customValidation {
        case .valid:
            return nil
        case .startAfterEnd:
            return t("Start date must not be after the end date.")
        case .tooWide:
            return t("Choose a shorter date range.")
        case .startTooFarInPast:
            return t("Choose a start date within the last 10 years.")
        }
    }

    private func handlePresetSelection(_ preset: HistoryDateRangePreset) {
        guard preset == .custom else {
            filter.preset = preset
            return
        }

        syncDraftDatesFromFilter()
        isShowingCustomRangeSheet = true
    }

    private func syncDraftDatesFromFilter() {
        draftStart = filter.customStart ?? Self.defaultStartDate
        draftEnd = filter.customEnd ?? Date()
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = preferences.appLocale
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}
#endif
