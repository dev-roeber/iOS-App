#if canImport(SwiftUI)
import SwiftUI

/// A compact pill/chip that shows the active date range filter and lets the
/// user open the full picker sheet or clear the filter with a single tap.
public struct HistoryDateRangeFilterBar: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var filter: HistoryDateRangeFilter
    @State private var isShowingPicker = false

    public init(filter: Binding<HistoryDateRangeFilter>) {
        self._filter = filter
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button {
                isShowingPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filter.isActive ? "calendar.badge.checkmark" : "calendar")
                        .font(.subheadline)
                    Text(localChipLabel)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filter.isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .foregroundStyle(filter.isActive ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(filter.isActive
                ? "\(t("Date Range")): \(localChipLabel). \(t("Tap to change."))"
                : t("All Days. Tap to filter by date range."))

            if filter.isActive {
                Button {
                    filter.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        // Expand the hit area beyond the 12×12 pt glyph so
                        // the button passes Apple's 44 pt touch-target HIG
                        // and is reliably hittable on hardware (real
                        // iPhone 15 Pro Max UITest run reported the button
                        // as not-hittable at 132×514 / 12×12). The visible
                        // glyph stays unchanged, only the tap area grows.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("Clear Date Range"))
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            HistoryDateRangePickerSheet(filter: $filter)
        }
    }

    private var localChipLabel: String {
        switch filter.preset {
        case .all: return t("All Days")
        case .last7Days: return t("Last 7 Days")
        case .last30Days: return t("Last 30 Days")
        case .last90Days: return t("Last 90 Days")
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)"
        case .custom:
            guard let start = filter.customStart, let end = filter.customEnd else {
                return t("Custom")
            }
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .none
            f.locale = preferences.appLocale
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
