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
    let presentation: DaySummaryRowPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.dayNumberText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(presentation.weekdayText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LH2GPXTheme.textSecondary)
            }
            .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.dateText)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let timeRangeText = presentation.timeRangeText {
                            Label(timeRangeText, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(LH2GPXTheme.textSecondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if isFavorited {
                            statusChip(title: t("Favorites"), systemImage: "star.fill", tint: LH2GPXTheme.favoriteYellow)
                                .accessibilityIdentifier("days.row.favorite.\(summary.date)")
                        }
                        if isSelectedForExport {
                            statusChip(title: t("Exported"), systemImage: "checkmark.circle.fill", tint: LH2GPXTheme.liveMint)
                                .accessibilityIdentifier("days.row.exported.\(summary.date)")
                        }
                        ForEach(highlightIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(LH2GPXTheme.textSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LH2GPXTheme.primaryBlue.opacity(0.85))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        metricPill(icon: "mappin.and.ellipse", text: presentation.placeText, tint: LH2GPXTheme.liveMint)
                        metricPill(icon: "location.north.line", text: presentation.routeText, tint: LH2GPXTheme.routeOrange)
                        if let distanceText = presentation.distanceText {
                            metricPill(icon: "ruler", text: distanceText, tint: LH2GPXTheme.distancePurple)
                        }
                        ForEach(presentation.metrics.filter { $0.id == "activities" }) { metric in
                            metricPill(icon: metric.icon, text: metric.text, tint: LH2GPXTheme.primaryBlue)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LH2GPXTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        .opacity(summary.hasContent ? 1 : 0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private func statusChip(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func metricPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }
}

struct AppDayFilterChipsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var filter: DayListFilter
    let availableChips: [DayListFilterChip]

    var body: some View {
        let visibleChips = availableChips.filter { [.hasRoutes, .favorites, .exportable].contains($0) }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: t("All"), isActive: !filter.isActive, identifier: "days.filter.all") {
                    filter.clearAll()
                }
                ForEach(visibleChips) { chip in
                    filterChip(
                        title: chipTitle(chip),
                        isActive: filter.activeChips.contains(chip),
                        identifier: chipIdentifier(chip)
                    ) {
                        filter.toggle(chip)
                    }
                }
            }
        }
    }

    private func chipTitle(_ chip: DayListFilterChip) -> String {
        switch chip {
        case .favorites:
            return t("Favorites")
        case .hasRoutes:
            return t("With Routes")
        case .exportable:
            return t("Exported")
        case .hasVisits, .hasDistance:
            return t("All")
        }
    }

    private func chipIdentifier(_ chip: DayListFilterChip) -> String {
        switch chip {
        case .favorites: return "days.filter.favorites"
        case .hasRoutes: return "days.filter.routes"
        case .exportable: return "days.filter.exported"
        case .hasVisits, .hasDistance: return "days.filter.all"
        }
    }

    private func filterChip(title: String, isActive: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? Color.black : LH2GPXTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? LH2GPXTheme.liveMint : LH2GPXTheme.elevatedCard)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
    let rangeSummaryText: String?
    let mapHeader: AnyView?
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
        rangeSummaryText: String? = nil,
        mapHeader: AnyView? = nil,
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
        self.rangeSummaryText = rangeSummaryText
        self.mapHeader = mapHeader
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
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(t("Days"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("days.title")
                        dayContextRow
                        if let mapHeader {
                            mapHeader
                                .accessibilityIdentifier("days.map.header")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }
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
                        .accessibilityIdentifier("days.month.\(group.id)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
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
            LHContextBar(
                message: exportSelectionText,
                systemImage: "checkmark.circle.fill",
                tint: LH2GPXTheme.liveMint
            )
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
        let presentation = DaySummaryRowPresentationBuilder.presentation(
            for: summary,
            unit: preferences.distanceUnit,
            context: .list,
            isFavorited: favoriteDayIDs.contains(summary.date),
            isExported: selectedForExportDates.contains(summary.date)
        )
        AppDayRow(
            summary: summary,
            highlightIcons: highlightIconsForDate(summary.date),
            isSelectedForExport: selectedForExportDates.contains(summary.date),
            isFavorited: favoriteDayIDs.contains(summary.date),
            presentation: presentation
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .tag(summary.date)
        .disabled(!summary.hasContent)
        .accessibilityIdentifier("days.row.\(summary.date)")
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
    private var dayContextRow: some View {
        HStack(spacing: 8) {
            contextPill(text: rangeSummaryText ?? t("All"), icon: "calendar", identifier: "days.range")
            contextPill(
                text: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? t("Days Search")
                    : searchText,
                icon: "magnifyingglass",
                identifier: "days.search"
            )
        }
    }

    private func contextPill(text: String, icon: String, identifier: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(LH2GPXTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(LH2GPXTheme.elevatedCard)
        .clipShape(Capsule())
        .accessibilityIdentifier(identifier)
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
