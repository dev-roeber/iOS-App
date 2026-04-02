#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Day Row

struct AppDayRow: View {
    @EnvironmentObject private var preferences: AppPreferences
    let summary: DaySummary
    var highlightIcons: [String] = []
    var isSelectedForExport: Bool = false
    var isFavorited: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(AppDateDisplay.weekday(summary.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    if isSelectedForExport {
                        Label(t("Export"), systemImage: "square.and.arrow.up")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if isFavorited {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    ForEach(highlightIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(AppDateDisplay.mediumDate(summary.date))
                .font(.headline)
            if summary.hasContent {
                HStack(spacing: 12) {
                    Label("\(summary.visitCount)", systemImage: "mappin.and.ellipse")
                    Label("\(summary.activityCount)", systemImage: "figure.walk")
                    Label("\(summary.pathCount)", systemImage: "location.north.line")
                    if summary.totalPathDistanceM > 0 {
                        Label(formatDistance(summary.totalPathDistanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel([
                    visitCountText(summary.visitCount),
                    activityCountText(summary.activityCount),
                    routeCountText(summary.pathCount)
                ].joined(separator: ", "))
            } else {
                Label(t("No recorded entries"), systemImage: "tray")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(t("No recorded entries for this day"))
                Text(t("No data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelectedForExport ? Color.accentColor.opacity(0.20) : Color.primary.opacity(summary.hasContent ? 0.035 : 0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(summary.hasContent ? 1 : 0.72)
    }

    private var rowBackground: Color {
        if isSelectedForExport {
            return Color.accentColor.opacity(0.06)
        }
        if summary.hasContent {
            return Color.secondary.opacity(0.018)
        }
        return Color.secondary.opacity(0.035)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func visitCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Besuch" : "Besuche")"
            : "\(count) \(count == 1 ? "Visit" : "Visits")"
    }

    private func activityCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Aktivität" : "Aktivitäten")"
            : "\(count) \(count == 1 ? "Activity" : "Activities")"
    }

    private func routeCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Route" : "Routen")"
            : "\(count) \(count == 1 ? "Route" : "Routes")"
    }
}

struct AppDayFilterChipsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var filter: DayListFilter
    let availableChips: [DayListFilterChip]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Filter Days"))
                        .font(.subheadline.weight(.semibold))
                    Text(t("Combine chips with search while keeping the newest day first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if filter.isActive {
                    Button(t("Clear Filters")) {
                        filter.clearAll()
                    }
                    .font(.caption.weight(.medium))
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(availableChips) { chip in
                    Button {
                        filter.toggle(chip)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.activeChips.contains(chip) ? "checkmark.circle.fill" : chip.systemImage)
                                .font(.caption)
                            Text(chipTitle(chip))
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(filter.activeChips.contains(chip) ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                        .foregroundStyle(filter.activeChips.contains(chip) ? Color.accentColor : Color.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chipTitle(_ chip: DayListFilterChip) -> String {
        switch chip {
        case .favorites:
            return t("Favorites")
        case .hasVisits:
            return t("Has Visits")
        case .hasRoutes:
            return t("Has Routes")
        case .hasDistance:
            return t("Has Distance")
        case .exportable:
            return t("Exportable")
        }
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

// MARK: - Day List (Selection-based, for regular layout)

public struct AppDayListView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let summaries: [DaySummary]
    let selectedForExportDates: Set<String>
    let favoriteDayIDs: Set<String>
    let drilldownDescription: String?
    let isRangeFilterActive: Bool
    @Binding var selectedDate: String?
    @Binding var filter: DayListFilter
    @Binding var searchText: String
    var onClearDrilldown: (() -> Void)? = nil
    var onToggleFavorite: ((String) -> Void)? = nil
    var highlightIconsForDate: (String) -> [String] = { _ in [] }

    public init(
        summaries: [DaySummary],
        selectedForExportDates: Set<String> = [],
        favoriteDayIDs: Set<String> = [],
        drilldownDescription: String? = nil,
        isRangeFilterActive: Bool = false,
        selectedDate: Binding<String?>,
        filter: Binding<DayListFilter> = .constant(.empty),
        onClearDrilldown: (() -> Void)? = nil,
        onToggleFavorite: ((String) -> Void)? = nil,
        highlightIconsForDate: @escaping (String) -> [String] = { _ in [] },
        searchText: Binding<String> = .constant("")
    ) {
        self.summaries = summaries
        self.selectedForExportDates = selectedForExportDates
        self.favoriteDayIDs = favoriteDayIDs
        self.drilldownDescription = drilldownDescription
        self.isRangeFilterActive = isRangeFilterActive
        self._selectedDate = selectedDate
        self._filter = filter
        self._searchText = searchText
        self.onClearDrilldown = onClearDrilldown
        self.onToggleFavorite = onToggleFavorite
        self.highlightIconsForDate = highlightIconsForDate
    }

    public var body: some View {
        let filteredSummaries = DayListPresentation.filteredSummaries(
            summaries,
            query: searchText,
            filter: filter,
            favorites: favoriteDayIDs
        )
        let availableChips = DayListPresentation.availableFilterChips(summaries: summaries, favorites: favoriteDayIDs)
        if summaries.isEmpty {
            AppDayListEmptyView()
        } else {
            let groups = groupByMonth(filteredSummaries, locale: preferences.appLocale)
            List(selection: $selectedDate) {
                if let drilldownDescription {
                    Section {
                        drilldownBanner(description: drilldownDescription)
                    }
                }
                if !availableChips.isEmpty || filter.isActive {
                    Section {
                        AppDayFilterChipsView(filter: $filter, availableChips: availableChips)
                    }
                }
                if !selectedForExportDates.isEmpty {
                    exportStatusSection
                }
                if groups.count == 1 {
                    ForEach(filteredSummaries, id: \.date) { summary in
                        interactiveRow(for: summary)
                    }
                } else {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.summaries, id: \.date) { summary in
                                interactiveRow(for: summary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if !summaries.isEmpty && filteredSummaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: isRangeFilterActive && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !filter.isActive ? "calendar.badge.exclamationmark" : "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(emptyHeadline)
                            .font(.headline)
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
            }
        }
    }

    private var exportStatusSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exportSelectionText)
                        .font(.subheadline.weight(.semibold))
                    Text(t("Export markers stay visible directly in the list."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var exportSelectionText: String {
        if preferences.appLanguage.isGerman {
            return "\(selectedForExportDates.count) \(selectedForExportDates.count == 1 ? "Tag" : "Tage") für den Export ausgewählt"
        }
        return "\(selectedForExportDates.count) day\(selectedForExportDates.count == 1 ? "" : "s") selected for export"
    }

    private var emptyHeadline: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRangeFilterActive && trimmed.isEmpty && !filter.isActive {
            return t("No Days in Range")
        }
        return filter.isActive ? t("No Matching Days") : t("No Results")
    }

    private var emptyMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filter.isActive {
            return tf("No days match \"%@\" with the current filters.", searchText)
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tf("No days match \"%@\".", searchText)
        }
        if isRangeFilterActive {
            return t("No days fall within the selected date range. Change the range to see more days.")
        }
        if drilldownDescription != nil {
            return t("No day matches the current drilldown and filter combination.")
        }
        return t("No day matches the active filter chips.")
    }

    @ViewBuilder
    private func interactiveRow(for summary: DaySummary) -> some View {
        AppDayRow(
            summary: summary,
            highlightIcons: highlightIconsForDate(summary.date),
            isSelectedForExport: selectedForExportDates.contains(summary.date),
            isFavorited: favoriteDayIDs.contains(summary.date)
        )
        .tag(summary.date)
        .disabled(!summary.hasContent)
        .contextMenu {
            if let onToggleFavorite {
                Button {
                    onToggleFavorite(summary.date)
                } label: {
                    Label(
                        favoriteDayIDs.contains(summary.date) ? t("Remove Favorite") : t("Add Favorite"),
                        systemImage: favoriteDayIDs.contains(summary.date) ? "star.slash" : "star"
                    )
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onToggleFavorite {
                Button {
                    onToggleFavorite(summary.date)
                } label: {
                    Label(
                        favoriteDayIDs.contains(summary.date) ? t("Unfavorite") : t("Favorite"),
                        systemImage: favoriteDayIDs.contains(summary.date) ? "star.slash.fill" : "star.fill"
                    )
                }
                .tint(favoriteDayIDs.contains(summary.date) ? .gray : .yellow)
            }
        }
    }

    @ViewBuilder
    private func drilldownBanner(description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Insights Drilldown"))
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onClearDrilldown {
                Button(t("Reset")) {
                    onClearDrilldown()
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(.vertical, 4)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private func tf(_ englishFormat: String, _ arguments: CVarArg...) -> String {
        preferences.localized(format: englishFormat, arguments: arguments)
    }
}

// MARK: - Day List Empty

struct AppDayListEmptyView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(t("No Days"))
                .font(.headline)
            Text(t("This export does not contain any day entries."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

#endif
