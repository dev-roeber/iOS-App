#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Charts)
import Charts
#endif

struct AppInsightsContentView: View {
    private struct InsightsDerivedModel {
        let trendItems: [InsightsMonthlyTrendItem]
        let availableWeekdayMetrics: [InsightsWeekdayMetric]
        let availablePeriodMetrics: [InsightsPeriodMetric]
        let availableTopDayMetrics: [InsightsTopDayMetric]
        let summaryCards: [InsightsSummaryCard]
        let highlightItems: [InsightsHighlightItem]
        let streakStat: InsightsStreakStat
        let periodComparisonStat: InsightsPeriodComparisonStat?
    }

    @EnvironmentObject private var preferences: AppPreferences

    let insights: ExportInsights
    let daySummaries: [DaySummary]
    /// Full (unfiltered) day summaries used to populate the prior period in Period Comparison.
    /// Pass `session.daySummaries` (not the range-projected list) here.
    let allDaySummaries: [DaySummary]
    let activeFilterDescriptions: [String]
    let onDrilldown: ((InsightsDrilldownAction) -> Void)?
    @Binding private var rangeFilter: HistoryDateRangeFilter

    @State private var activityMetric: ActivityMetric = .count
    @State private var topDayMetric: InsightsTopDayMetric = .events
    @State private var trendMetric: InsightsTrendMetric = .distance
    @State private var weekdayMetric: InsightsWeekdayMetric = .events
    @State private var periodMetric: InsightsPeriodMetric = .events
    @State private var surfaceMode: InsightsSurfaceMode = .overview
    @State private var pendingDrilldownTitle = ""
    @State private var pendingDrilldownTargets: [InsightsDrilldownTarget] = []
    @State private var shareSheetPayload: InsightsRenderedSharePayload?
    @State private var shareError: String?
    @State private var derivedModel: InsightsDerivedModel?

    init(
        insights: ExportInsights,
        daySummaries: [DaySummary] = [],
        allDaySummaries: [DaySummary] = [],
        rangeFilter: Binding<HistoryDateRangeFilter> = .constant(.default),
        activeFilterDescriptions: [String]? = nil,
        onDrilldown: ((InsightsDrilldownAction) -> Void)? = nil
    ) {
        self.insights = insights
        self.daySummaries = daySummaries
        self.allDaySummaries = allDaySummaries
        self.activeFilterDescriptions = activeFilterDescriptions ?? insights.activeFilterDescriptions
        self.onDrilldown = onDrilldown
        self._rangeFilter = rangeFilter
    }

    private enum InsightsSurfaceMode: String, CaseIterable {
        case overview = "Overview"
        case patterns = "Patterns"
        case breakdowns = "Breakdowns"
    }

    private var resolvedDerivedModel: InsightsDerivedModel {
        if let derivedModel {
            return derivedModel
        }

        let builtTrendItems = InsightsMonthlyTrendPresentation.items(from: daySummaries, locale: preferences.appLocale)
        return InsightsDerivedModel(
            trendItems: builtTrendItems,
            availableWeekdayMetrics: InsightsChartSupport.availableWeekdayMetrics(for: daySummaries),
            availablePeriodMetrics: InsightsChartSupport.availablePeriodMetrics(for: insights.periodBreakdown),
            availableTopDayMetrics: InsightsTopDaysPresentation.availableMetrics(for: daySummaries),
            summaryCards: buildSummaryCards(trendItemCount: builtTrendItems.count),
            highlightItems: buildHighlightItems(),
            streakStat: InsightsStreakPresentation.streak(from: daySummaries),
            periodComparisonStat: InsightsPeriodComparisonPresentation.comparison(
                currentSummaries: daySummaries,
                allSummaries: allDaySummaries,
                rangeFilter: rangeFilter
            )
        )
    }

    private var trendItems: [InsightsMonthlyTrendItem] {
        resolvedDerivedModel.trendItems
    }

    private var availableWeekdayMetrics: [InsightsWeekdayMetric] {
        resolvedDerivedModel.availableWeekdayMetrics
    }

    private var weekdayStats: [InsightsWeekdayMetricStat] {
        InsightsChartSupport.weekdayStats(
            from: daySummaries,
            metric: weekdayMetric,
            locale: preferences.appLocale
        )
    }

    private var availablePeriodMetrics: [InsightsPeriodMetric] {
        resolvedDerivedModel.availablePeriodMetrics
    }

    private var availableTopDayMetrics: [InsightsTopDayMetric] {
        resolvedDerivedModel.availableTopDayMetrics
    }

    private var topDays: [DaySummary] {
        InsightsTopDaysPresentation.topDays(from: daySummaries, by: topDayMetric, limit: 5)
    }

    private var summaryCards: [InsightsSummaryCard] {
        resolvedDerivedModel.summaryCards
    }

    private var highlightItems: [InsightsHighlightItem] {
        resolvedDerivedModel.highlightItems
    }

    private var streakStat: InsightsStreakStat {
        resolvedDerivedModel.streakStat
    }

    private var periodComparisonStat: InsightsPeriodComparisonStat? {
        resolvedDerivedModel.periodComparisonStat
    }

    private var hasAnyMeaningfulInsightSection: Bool {
        !daySummaries.isEmpty &&
        (
            daySummaries.contains(where: { $0.totalPathDistanceM > 0 }) ||
            !insights.activityBreakdown.isEmpty ||
            !insights.visitTypeBreakdown.isEmpty ||
            !insights.periodBreakdown.isEmpty ||
            !highlightItems.isEmpty
        )
    }

    var body: some View {
        if daySummaries.isEmpty {
            pageEmptyState(
                title: t("No Insights Yet"),
                message: t("This import contains no day entries, so there is nothing meaningful to analyze yet."),
                systemImage: "chart.line.text.clipboard"
            )
        } else {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                AppHistoryDateRangeControl(filter: $rangeFilter)

                if !hasAnyMeaningfulInsightSection {
                    insightsEmptyCard(
                        title: t("Limited Insight Data"),
                        message: t("The import loaded correctly, but it does not contain enough structured data for the current insight views yet."),
                        systemImage: "chart.bar.xaxis"
                    )
                }

                Picker("", selection: $surfaceMode) {
                    ForEach(InsightsSurfaceMode.allCases, id: \.self) { mode in
                        Text(t(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch surfaceMode {
                case .overview:
                    overviewSections
                case .patterns:
                    patternSections
                case .breakdowns:
                    breakdownSections
                }
            }
            .onAppear {
                refreshDerivedModel()
            }
            .onChange(of: insights) { _ in refreshDerivedModel() }
            .onChange(of: daySummaries) { _ in refreshDerivedModel() }
            .onChange(of: rangeFilter) { _ in refreshDerivedModel() }
            .onChange(of: preferences.distanceUnit) { _ in refreshDerivedModel() }
            .onChange(of: preferences.appLanguage) { _ in refreshDerivedModel() }
            .confirmationDialog(
                pendingDrilldownTitle,
                isPresented: Binding(
                    get: { !pendingDrilldownTargets.isEmpty },
                    set: { if !$0 { pendingDrilldownTargets = [] } }
                ),
                titleVisibility: .visible
            ) {
                ForEach(pendingDrilldownTargets) { target in
                    Button(t(target.label)) {
                        pendingDrilldownTargets = []
                        onDrilldown?(target.action)
                    }
                }
                Button(t("Cancel"), role: .cancel) {
                    pendingDrilldownTargets = []
                }
            } message: {
                Text(t("Choose where to continue with this insight."))
            }
            .sheet(item: $shareSheetPayload) { payload in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(payload.title)
                            .font(.headline)
                        Text(payload.filename)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ShareLink(item: payload.url) {
                            Label(t("Share Chart"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                    .navigationTitle(t("Share"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(t("Done")) {
                                shareSheetPayload = nil
                            }
                        }
                    }
                }
            }
            .alert(
                t("Share Failed"),
                isPresented: Binding(
                    get: { shareError != nil },
                    set: { if !$0 { shareError = nil } }
                )
            ) {
                Button(t("OK"), role: .cancel) {
                    shareError = nil
                }
            } message: {
                Text(shareError ?? "")
            }
        }
    }

    private func refreshDerivedModel() {
        let builtTrendItems = InsightsMonthlyTrendPresentation.items(from: daySummaries, locale: preferences.appLocale)
        let builtTopDayMetrics = InsightsTopDaysPresentation.availableMetrics(for: daySummaries)
        let builtWeekdayMetrics = InsightsChartSupport.availableWeekdayMetrics(for: daySummaries)
        let builtPeriodMetrics = InsightsChartSupport.availablePeriodMetrics(for: insights.periodBreakdown)
        let availableTrendMetrics = InsightsMonthlyTrendPresentation.availableMetrics(for: builtTrendItems)

        derivedModel = InsightsDerivedModel(
            trendItems: builtTrendItems,
            availableWeekdayMetrics: builtWeekdayMetrics,
            availablePeriodMetrics: builtPeriodMetrics,
            availableTopDayMetrics: builtTopDayMetrics,
            summaryCards: buildSummaryCards(trendItemCount: builtTrendItems.count),
            highlightItems: buildHighlightItems(),
            streakStat: InsightsStreakPresentation.streak(from: daySummaries),
            periodComparisonStat: InsightsPeriodComparisonPresentation.comparison(
                currentSummaries: daySummaries,
                allSummaries: allDaySummaries,
                rangeFilter: rangeFilter
            )
        )

        if let firstTopMetric = builtTopDayMetrics.first, !builtTopDayMetrics.contains(topDayMetric) {
            topDayMetric = firstTopMetric
        }
        if let firstTrendMetric = availableTrendMetrics.first,
           !availableTrendMetrics.contains(trendMetric) {
            trendMetric = firstTrendMetric
        }
        if let firstWeekdayMetric = builtWeekdayMetrics.first, !builtWeekdayMetrics.contains(weekdayMetric) {
            weekdayMetric = firstWeekdayMetric
        }
        if let firstPeriodMetric = builtPeriodMetrics.first, !builtPeriodMetrics.contains(periodMetric) {
            periodMetric = firstPeriodMetric
        }
    }

    private func buildSummaryCards(trendItemCount: Int) -> [InsightsSummaryCard] {
        let activeDays = daySummaries.filter(\.hasContent).count
        return [
            InsightsSummaryCard(
                title: t("Days Loaded"),
                value: "\(daySummaries.count)",
                subtitle: insights.dateRange.map { "\(AppDateDisplay.mediumDate($0.firstDate)) – \(AppDateDisplay.mediumDate($0.lastDate))" },
                icon: "calendar",
                color: .blue
            ),
            InsightsSummaryCard(
                title: t("Active Days"),
                value: daySummaries.isEmpty ? "0" : "\(activeDays) / \(daySummaries.count)",
                subtitle: t("Days with tracked activity"),
                icon: "checkmark.circle",
                color: .teal
            ),
            InsightsSummaryCard(
                title: t("Total Distance"),
                value: formatDistance(insights.totalDistanceM, unit: preferences.distanceUnit),
                subtitle: t("Route distance with trace fallback"),
                icon: "road.lanes",
                color: .purple
            ),
            InsightsSummaryCard(
                title: t("Average Distance / Day"),
                value: formatDistance(insights.averagesPerDay.avgDistancePerDayM, unit: preferences.distanceUnit),
                subtitle: t("Across visible days"),
                icon: "chart.line.uptrend.xyaxis",
                color: .indigo
            ),
            InsightsSummaryCard(
                title: t("Active Months"),
                value: "\(trendItemCount)",
                subtitle: t("Months with visible day entries"),
                icon: "calendar.badge.clock",
                color: .orange
            ),
        ]
    }

    private func buildHighlightItems() -> [InsightsHighlightItem] {
        var items: [InsightsHighlightItem] = []

        if let busiestDay = insights.busiestDay {
            items.append(
                InsightsCardPresentation.highlightItem(
                    id: "busiest",
                    title: t("Busiest Day"),
                    icon: "flame.fill",
                    color: .orange,
                    highlight: busiestDay,
                    summary: daySummaries.first(where: { $0.date == busiestDay.date }),
                    unit: preferences.distanceUnit
                )
            )
        }
        if let mostVisitsDay = insights.mostVisitsDay {
            items.append(
                InsightsCardPresentation.highlightItem(
                    id: "visits",
                    title: t("Most Visits"),
                    icon: "mappin.and.ellipse",
                    color: .blue,
                    highlight: mostVisitsDay,
                    summary: daySummaries.first(where: { $0.date == mostVisitsDay.date }),
                    unit: preferences.distanceUnit
                )
            )
        }
        if let mostRoutesDay = insights.mostRoutesDay {
            items.append(
                InsightsCardPresentation.highlightItem(
                    id: "routes",
                    title: t("Most Routes"),
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    color: .green,
                    highlight: mostRoutesDay,
                    summary: daySummaries.first(where: { $0.date == mostRoutesDay.date }),
                    unit: preferences.distanceUnit
                )
            )
        }
        if let longestDistanceDay = insights.longestDistanceDay {
            items.append(
                InsightsCardPresentation.highlightItem(
                    id: "distance",
                    title: t("Longest Distance"),
                    icon: "road.lanes",
                    color: .purple,
                    highlight: longestDistanceDay,
                    summary: daySummaries.first(where: { $0.date == longestDistanceDay.date }),
                    unit: preferences.distanceUnit
                )
            )
        }

        return items
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("Insights Overview"))
                    .font(.title2.weight(.semibold))
                Text(t("Switch between a concise overview, recurring patterns and deeper breakdowns without leaving the current import."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !activeFilterDescriptions.isEmpty {
                activeFilterBanner
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(summaryCards) { card in
                    summaryCard(card)
                }
            }
        }
    }

    @ViewBuilder
    private var overviewSections: some View {
        if !highlightItems.isEmpty {
            insightSection(t("Highlights"), icon: "sparkles", shareCardType: .highlights) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(highlightItems) { item in
                        if onDrilldown != nil {
                            Button {
                                presentDrilldown(
                                    title: "\(t("Highlights")) · \(AppDateDisplay.mediumDate(item.date))",
                                    targets: dayDrilldownTargets(for: item.date)
                                )
                            } label: {
                                InsightsHighlightCardView(item: item, isInteractive: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            InsightsHighlightCardView(item: item, isInteractive: false)
                        }
                    }
                }
            }
        }

        insightSection(t("Daily Averages"), icon: "chart.bar.fill") {
            if let dailyAverageHint = InsightsChartSupport.dailyAveragesSectionMessage(dayCount: daySummaries.count) {
                insightsEmptyCard(
                    title: t("Need More Than One Day"),
                    message: t(dailyAverageHint),
                    systemImage: "calendar.badge.plus"
                )
            } else {
                let averages = insights.averagesPerDay
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    avgCard(String(format: "%.1f", averages.avgVisitsPerDay), label: t("Visits / Day"), icon: "mappin.and.ellipse", color: .blue)
                    avgCard(String(format: "%.1f", averages.avgActivitiesPerDay), label: t("Activities / Day"), icon: "figure.walk", color: .green)
                    avgCard(String(format: "%.1f", averages.avgPathsPerDay), label: t("Routes / Day"), icon: "location.north.line", color: .orange)
                    avgCard(formatDistance(averages.avgDistancePerDayM, unit: preferences.distanceUnit), label: t("Distance / Day"), icon: "road.lanes", color: .purple)
                }
            }
        }

        streakSection

        topDaysSection
    }

    @ViewBuilder
    private var patternSections: some View {
        insightSection(t("Distance Over Time"), icon: "chart.bar.fill") {
            #if canImport(Charts)
            if InsightsChartSupport.hasDistanceData(in: daySummaries) {
                distanceChart
                sectionHint(t(InsightsChartSupport.distanceSectionMessage(hasDays: true, canNavigateToDay: onDrilldown != nil)))
            } else {
                insightsEmptyCard(
                    title: t("No Route Distances"),
                    message: t(InsightsChartSupport.distanceEmptyMessage()),
                    systemImage: "road.lanes"
                )
            }
            #else
            insightsEmptyCard(
                title: t("Charts Unavailable"),
                message: t("This platform build does not include chart rendering for the distance timeline."),
                systemImage: "chart.bar"
            )
            #endif
        }

        insightSection(t("Monthly Trends"), icon: "calendar.badge.clock", shareCardType: .monthlyTrend) {
            #if canImport(Charts)
            if !trendItems.isEmpty {
                Picker("", selection: $trendMetric) {
                    ForEach(InsightsMonthlyTrendPresentation.availableMetrics(for: trendItems), id: \.self) { metric in
                        Text(t(metric.rawValue)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                monthlyTrendChart
                sectionHint(t("Spot month-to-month changes in visible route distance, visits, routes or total activity volume."))
                monthlyTrendRows
            } else {
                insightsEmptyCard(
                    title: t("No Monthly Trend Yet"),
                    message: t("At least one month with visible days is required before this trend becomes meaningful."),
                    systemImage: "calendar"
                )
            }
            #else
            insightsEmptyCard(
                title: t("Charts Unavailable"),
                message: t("This platform build does not include chart rendering for monthly trends."),
                systemImage: "chart.bar"
            )
            #endif
        }

        insightSection(t("By Day of Week"), icon: "chart.bar", shareCardType: .weekdayPattern) {
            #if canImport(Charts)
            if !weekdayStats.isEmpty {
                Picker("", selection: $weekdayMetric) {
                    ForEach(availableWeekdayMetrics, id: \.self) { metric in
                        Text(t(metric.rawValue)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                weekdayChart
                if let message = InsightsChartSupport.weekdaySectionMessage(dayCount: daySummaries.count, bucketCount: weekdayStats.count) {
                    sectionHint(t(message))
                } else {
                    sectionHint(t(InsightsChartSupport.weekdaySectionHint(for: weekdayMetric)))
                }
            } else {
                insightsEmptyCard(
                    title: t("Need More Day Coverage"),
                    message: t("A weekday pattern is only shown once at least three separate day summaries are available."),
                    systemImage: "calendar"
                )
            }
            #else
            insightsEmptyCard(
                title: t("Charts Unavailable"),
                message: t("This platform build does not include chart rendering for the weekday view."),
                systemImage: "chart.bar"
            )
            #endif
        }

        periodComparisonSection
    }

    @ViewBuilder
    private var breakdownSections: some View {
        topDaysSection

        insightSection(t("Activity Types"), icon: "figure.walk", shareCardType: .activityBreakdown) {
            if !insights.activityBreakdown.isEmpty {
                #if canImport(Charts)
                Picker("", selection: $activityMetric) {
                    ForEach(InsightsChartSupport.availableActivityMetrics(for: insights.activityBreakdown), id: \.self) { metric in
                        Text(t(metric.rawValue)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                activityTypeChart
                sectionHint(activityMetric == .distance ? t("Compare activities by covered distance.") : t("Compare activities by entry count."))
                #endif

                ForEach(Array(insights.activityBreakdown.enumerated()), id: \.offset) { _, item in
                    activityBreakdownCard(item)
                }
            } else {
                insightsEmptyCard(
                    title: t("No Activity Breakdown"),
                    message: t(InsightsChartSupport.activitySectionEmptyMessage()),
                    systemImage: "figure.walk.motion"
                )
            }
        }

        insightSection(t("Visit Types"), icon: "mappin.and.ellipse") {
            if !insights.visitTypeBreakdown.isEmpty {
                #if canImport(Charts)
                visitTypeChart
                #endif

                ForEach(Array(insights.visitTypeBreakdown.enumerated()), id: \.offset) { _, item in
                    visitTypeRow(item)
                }
            } else {
                insightsEmptyCard(
                    title: t("No Visit Types"),
                    message: t(InsightsChartSupport.visitSectionEmptyMessage()),
                    systemImage: "mappin.slash"
                )
            }
        }

        insightSection(t("Period Breakdown"), icon: "calendar.badge.clock", shareCardType: .periodBreakdown) {
            if !insights.periodBreakdown.isEmpty {
                #if canImport(Charts)
                Picker("", selection: $periodMetric) {
                    ForEach(availablePeriodMetrics, id: \.self) { metric in
                        Text(t(metric.rawValue)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                periodBreakdownChart
                sectionHint(t(InsightsChartSupport.periodSectionHint(for: periodMetric)))
                #endif

                ForEach(Array(insights.periodBreakdown.enumerated()), id: \.offset) { _, item in
                    if let targets = periodDrilldownTargets(for: item), onDrilldown != nil {
                        Button {
                            presentDrilldown(title: "\(t("Period Breakdown")) · \(item.label)", targets: targets)
                        } label: {
                            periodRow(item, isInteractive: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        periodRow(item, isInteractive: false)
                    }
                }
            } else {
                insightsEmptyCard(
                    title: t("No Period Stats"),
                    message: t(InsightsChartSupport.periodSectionEmptyMessage()),
                    systemImage: "calendar.badge.exclamationmark"
                )
            }
        }
    }

    @ViewBuilder
    private var streakSection: some View {
        insightSection(t("Activity Streak"), icon: "flame.fill", shareCardType: .streak) {
            if let hint = InsightsChartSupport.dailyAveragesSectionMessage(dayCount: daySummaries.count) {
                insightsEmptyCard(
                    title: t("Not Enough Days"),
                    message: t(hint),
                    systemImage: "flame"
                )
            } else if streakStat.activeDaysCount == 0 {
                insightsEmptyCard(
                    title: t("No Active Days"),
                    message: t(InsightsStreakPresentation.noDataMessage()),
                    systemImage: "flame"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    streakCard(
                        value: "\(streakStat.recentStreakDays)",
                        unit: t(streakStat.recentStreakDays == 1 ? "day" : "days"),
                        label: t("Recent Streak"),
                        icon: "flame",
                        color: .orange,
                        detail: streakStat.recentStreakStart.map { AppDateDisplay.mediumDate($0) }
                    )
                    streakCard(
                        value: "\(streakStat.longestStreakDays)",
                        unit: t(streakStat.longestStreakDays == 1 ? "day" : "days"),
                        label: t("Best Streak"),
                        icon: "trophy",
                        color: .yellow,
                        detail: streakDateRangeLabel(start: streakStat.longestStreakStart, end: streakStat.longestStreakEnd)
                    )
                }
                sectionHint(t("Consecutive days with tracked activity in the visible range."))
            }
        }
    }

    @ViewBuilder
    private var periodComparisonSection: some View {
        insightSection(t("Period Comparison"), icon: "arrow.left.arrow.right", shareCardType: .periodComparison) {
            if let comparison = periodComparisonStat {
                periodComparisonRows(comparison)
                sectionHint(t(InsightsPeriodComparisonPresentation.sectionHint()))
            } else {
                insightsEmptyCard(
                    title: t("No Range Active"),
                    message: t(InsightsPeriodComparisonPresentation.noRangeMessage()),
                    systemImage: "arrow.left.arrow.right"
                )
            }
        }
    }

    @ViewBuilder
    private func periodComparisonRows(_ stat: InsightsPeriodComparisonStat) -> some View {
        VStack(spacing: 0) {
            periodComparisonHeader(current: stat.current.label, prior: stat.prior.label)
            Divider()
            periodComparisonRow(
                label: t("Active Days"),
                icon: "checkmark.circle",
                current: Double(stat.current.activeDays),
                prior: Double(stat.prior.activeDays),
                format: { "\(Int($0))" }
            )
            Divider()
            periodComparisonRow(
                label: t("Events"),
                icon: "chart.bar",
                current: Double(stat.current.events),
                prior: Double(stat.prior.events),
                format: { "\(Int($0))" }
            )
            Divider()
            periodComparisonRow(
                label: t("Distance"),
                icon: "road.lanes",
                current: stat.current.distanceM,
                prior: stat.prior.distanceM,
                format: { formatDistance($0, unit: preferences.distanceUnit) }
            )
        }
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func periodComparisonHeader(current: String, prior: String) -> some View {
        HStack {
            Spacer()
            Text(prior)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(current)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .trailing)
            Text(t("Δ"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func periodComparisonRow(
        label: String,
        icon: String,
        current: Double,
        prior: Double,
        format: (Double) -> String
    ) -> some View {
        let delta = InsightsPeriodComparisonPresentation.deltaText(current: current, prior: prior)
        let isPositive = InsightsPeriodComparisonPresentation.isPositiveDelta(current: current, prior: prior)
        let deltaColor: Color = {
            guard let positive = isPositive else { return .secondary }
            return positive ? .green : .red
        }()

        return HStack {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(format(prior))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(format(current))
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 80, alignment: .trailing)
            Text(delta)
                .font(.caption.monospacedDigit())
                .foregroundStyle(deltaColor)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func streakCard(value: String, unit: String, label: String, icon: String, color: Color, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func streakDateRangeLabel(start: String?, end: String?) -> String? {
        guard let start else { return nil }
        guard let end, end != start else { return AppDateDisplay.mediumDate(start) }
        return "\(AppDateDisplay.mediumDate(start)) – \(AppDateDisplay.mediumDate(end))"
    }

    @ViewBuilder
    private var topDaysSection: some View {
        insightSection(t("Top Days"), icon: "list.number", shareCardType: .topDays) {
            if !topDays.isEmpty {
                Picker("", selection: $topDayMetric) {
                    ForEach(availableTopDayMetrics, id: \.self) { metric in
                        Text(t(metric.rawValue)).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                sectionHint(t(InsightsTopDaysPresentation.sectionMessage(metric: topDayMetric, canNavigateToDay: onDrilldown != nil)))

                VStack(spacing: 10) {
                    ForEach(Array(topDays.enumerated()), id: \.offset) { index, summary in
                        let presentation = InsightsCardPresentation.topDayRow(
                            summary: summary,
                            rank: index + 1,
                            metric: topDayMetric,
                            unit: preferences.distanceUnit
                        )

                        if onDrilldown != nil {
                            Button {
                                presentDrilldown(
                                    title: "\(t("Top Days")) · \(AppDateDisplay.mediumDate(summary.date))",
                                    targets: dayDrilldownTargets(for: summary.date)
                                )
                            } label: {
                                InsightsTopDayRowView(
                                    presentation: presentation,
                                    accent: accentColor(for: topDayMetric),
                                    isInteractive: true
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            InsightsTopDayRowView(
                                presentation: presentation,
                                accent: accentColor(for: topDayMetric),
                                isInteractive: false
                            )
                        }
                    }
                }
            } else {
                insightsEmptyCard(
                    title: t("No Ranked Days Yet"),
                    message: t("Visible day summaries need at least one visit, route or distance signal before they can be ranked."),
                    systemImage: "list.number"
                )
            }
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(
        _ title: String,
        icon: String,
        shareCardType: InsightsCardType? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(title, systemImage: icon)
                    .font(.title3.weight(.semibold))
                Spacer()
                if let shareCardType, supportsChartSharing {
                    Button {
                        prepareChartShare(
                            cardType: shareCardType,
                            title: title,
                            icon: icon,
                            content: content()
                        )
                    } label: {
                        Label(t("Share"), systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
            content()
        }
        .padding(18)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var activeFilterBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("Active Filters"), systemImage: "line.3.horizontal.decrease.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(activeFilterDescriptions.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pageEmptyState(title: String, message: String, systemImage: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }

    private func insightsEmptyCard(title: String, message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionHint(_ text: String, systemImage: String = "info.circle") -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func summaryCard(_ card: InsightsSummaryCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(card.title, systemImage: card.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(card.color)
            Text(card.value)
                .font(.title3.weight(.semibold).monospacedDigit())
            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(card.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func avgCard(_ value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func activityBreakdownCard(_ item: ActivityBreakdownItem) -> some View {
        let color = colorForActivityType(item.activityType)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForActivityType(item.activityType))
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(t(displayNameForActivityType(item.activityType)))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(item.count)×")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            HStack(spacing: 16) {
                if item.totalDistanceKM > 0 {
                    Label(formatDistance(item.totalDistanceKM * 1000, unit: preferences.distanceUnit), systemImage: "ruler")
                }
                if item.totalDurationH > 0 {
                    Label(formatDuration(item.totalDurationH), systemImage: "clock")
                }
                if item.avgSpeedKMH > 0 {
                    Label(formatSpeed(item.avgSpeedKMH, unit: preferences.distanceUnit), systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func visitTypeRow(_ item: VisitTypeItem) -> some View {
        HStack {
            Image(systemName: iconForVisitType(item.semanticType))
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(t(item.semanticType.capitalized))
                .font(.subheadline)
            Spacer()
            Text("\(item.count)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var monthlyTrendRows: some View {
        VStack(spacing: 10) {
            ForEach(trendItems) { item in
                if let targets = monthlyTrendDrilldownTargets(for: item), onDrilldown != nil {
                    Button {
                        presentDrilldown(title: "\(t("Monthly Trends")) · \(item.label)", targets: targets)
                    } label: {
                        monthlyTrendRow(item, isInteractive: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    monthlyTrendRow(item, isInteractive: false)
                }
            }
        }
    }

    private func monthlyTrendRow(_ item: InsightsMonthlyTrendItem, isInteractive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isInteractive {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(InsightsMonthlyTrendPresentation.summary(for: item, metric: trendMetric))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.indigo.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func periodRow(_ item: PeriodBreakdownItem, isInteractive: Bool) -> some View {
        let periodColor = item.distanceM > 0 ? Color.purple : Color.secondary
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isInteractive {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                Label(dayCountText(item.days), systemImage: "calendar")
                Label(visitCountText(item.visits), systemImage: "mappin.and.ellipse")
                Label(activityCountText(item.activities), systemImage: "figure.walk")
                if item.distanceM > 0 {
                    Label(formatDistance(item.distanceM, unit: preferences.distanceUnit), systemImage: "ruler")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(periodColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    #if canImport(Charts)
    private var distanceChart: some View {
        Chart {
            ForEach(daySummaries, id: \.date) { summary in
                if let date = insightsChartDateFormatter.date(from: summary.date) {
                    BarMark(
                        x: .value("Date", date, unit: .day),
                        y: .value(distanceAxisLabel(unit: preferences.distanceUnit), distanceValue(summary.totalPathDistanceM, unit: preferences.distanceUnit))
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxisLabel(distanceAxisLabel(unit: preferences.distanceUnit), alignment: .trailing)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard onDrilldown != nil else { return }
                        let x = location.x - geometry.frame(in: .local).minX
                        guard let tappedDate: Date = proxy.value(atX: x),
                              let nearestDate = InsightsChartSupport.nearestDayISODate(to: tappedDate, in: daySummaries.map(\.date)) else {
                            return
                        }
                        presentDrilldown(
                            title: "\(t("Distance Over Time")) · \(AppDateDisplay.mediumDate(nearestDate))",
                            targets: dayDrilldownTargets(for: nearestDate)
                        )
                    }
            }
        }
        .frame(height: 180)
    }

    private var monthlyTrendChart: some View {
        Chart {
            ForEach(trendItems) { item in
                let rawValue = InsightsMonthlyTrendPresentation.value(for: item, metric: trendMetric)
                let plottedValue = trendMetric == .distance ? distanceValue(rawValue, unit: preferences.distanceUnit) : rawValue
                BarMark(
                    x: .value(t("Month"), item.label),
                    y: .value(t(axisLabel(for: trendMetric)), plottedValue)
                )
                .foregroundStyle(accentColor(for: trendMetric).gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(trendMetric == .distance ? formatDistance(rawValue, unit: preferences.distanceUnit) : "\(Int(rawValue))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxisLabel(t(axisLabel(for: trendMetric)), alignment: .trailing)
        .frame(height: 220)
    }

    private var periodBreakdownChart: some View {
        Chart {
            ForEach(insights.periodBreakdown, id: \.label) { item in
                let rawValue = InsightsChartSupport.periodMetricValue(for: item, metric: periodMetric)
                let plottedValue = periodMetric == .distance ? distanceValue(rawValue, unit: preferences.distanceUnit) : rawValue
                BarMark(
                    x: .value(periodAxisLabel(for: periodMetric), plottedValue),
                    y: .value(t("Period"), item.label)
                )
                .foregroundStyle(periodAccentColor(for: periodMetric).gradient)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(periodMetric == .distance ? formatDistance(rawValue, unit: preferences.distanceUnit) : "\(Int(rawValue))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartXAxisLabel(periodAxisLabel(for: periodMetric), alignment: .trailing)
        .frame(height: CGFloat(max(insights.periodBreakdown.count, 1)) * 42 + 12)
    }

    private var activityTypeChart: some View {
        Chart {
            ForEach(insights.activityBreakdown, id: \.activityType) { item in
                let rawValue = activityMetric == .distance ? item.totalDistanceKM * 1000 : Double(item.count)
                let plottedValue = activityMetric == .distance ? distanceValue(rawValue, unit: preferences.distanceUnit) : rawValue
                BarMark(
                    x: .value(activityMetric == .distance ? distanceAxisLabel(unit: preferences.distanceUnit) : t("Count"), plottedValue),
                    y: .value(t("Type"), t(item.activityType.capitalized))
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(activityMetric == .distance ? formatDistance(rawValue, unit: preferences.distanceUnit) : "\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartXAxisLabel(activityMetric == .distance ? distanceAxisLabel(unit: preferences.distanceUnit) : t("Count"), alignment: .trailing)
        .frame(height: CGFloat(max(insights.activityBreakdown.count, 1)) * 42 + 12)
    }

    private var visitTypeChart: some View {
        Chart {
            ForEach(insights.visitTypeBreakdown, id: \.semanticType) { item in
                BarMark(
                    x: .value(t("Count"), item.count),
                    y: .value(t("Type"), t(item.semanticType.capitalized))
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartXAxisLabel(t("Visit Count"), alignment: .trailing)
        .frame(height: CGFloat(max(insights.visitTypeBreakdown.count, 1)) * 42 + 12)
    }

    private var weekdayChart: some View {
        Chart {
            ForEach(weekdayStats) { stat in
                let rawValue = stat.averageValue
                let plottedValue = weekdayMetric == .distance ? distanceValue(rawValue, unit: preferences.distanceUnit) : rawValue
                BarMark(
                    x: .value(t("Day"), stat.label),
                    y: .value(weekdayAxisLabel(for: weekdayMetric), plottedValue)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(
                        weekdayMetric == .distance
                            ? formatDistance(rawValue, unit: preferences.distanceUnit)
                            : String(format: "%.1f", rawValue)
                    )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxisLabel(weekdayAxisLabel(for: weekdayMetric), alignment: .trailing)
        .frame(height: 150)
    }
    #endif

    private var supportsChartSharing: Bool {
        #if os(iOS) || os(macOS)
        if #available(iOS 16.0, macOS 13.0, *) {
            return true
        }
        #endif
        return false
    }

    private func dayDrilldownTargets(for date: String) -> [InsightsDrilldownTarget] {
        [
            InsightsDrilldownTarget.showDay(date),
            InsightsDrilldownTarget.exportDay(date),
        ]
    }

    private func monthlyTrendDrilldownTargets(for item: InsightsMonthlyTrendItem) -> [InsightsDrilldownTarget]? {
        guard let range = InsightsDrilldownBridge.monthDateRange(for: item.monthKey) else {
            return nil
        }
        return dateRangeDrilldownTargets(fromDate: range.fromDate, toDate: range.toDate)
    }

    private func periodDrilldownTargets(for item: PeriodBreakdownItem) -> [InsightsDrilldownTarget]? {
        guard let range = InsightsDrilldownBridge.dateRange(for: item) else {
            return nil
        }
        return dateRangeDrilldownTargets(fromDate: range.fromDate, toDate: range.toDate)
    }

    private func dateRangeDrilldownTargets(fromDate: String, toDate: String) -> [InsightsDrilldownTarget] {
        [
            InsightsDrilldownTarget(
                label: "Show in Days",
                systemImage: "calendar",
                action: .filterDaysToDateRange(fromDate: fromDate, toDate: toDate)
            ),
            InsightsDrilldownTarget(
                label: "Export This Period",
                systemImage: "square.and.arrow.up",
                action: .prefillExportForDateRange(fromDate: fromDate, toDate: toDate)
            ),
        ]
    }

    private func presentDrilldown(title: String, targets: [InsightsDrilldownTarget]) {
        guard !targets.isEmpty else {
            return
        }
        pendingDrilldownTitle = title
        pendingDrilldownTargets = targets
    }

    private func prepareChartShare<Content: View>(
        cardType: InsightsCardType,
        title: String,
        icon: String,
        content: Content
    ) {
        #if os(iOS) || os(macOS)
        guard supportsChartSharing else {
            shareError = t("Chart sharing requires a newer Apple platform version.")
            return
        }

        if #available(iOS 16.0, macOS 13.0, *) {
            let payload = ChartShareHelper.payload(for: cardType, dateRange: rangeFilter)
            let captureView = InsightsShareCaptureView(
                title: title,
                icon: icon,
                content: content
            )
            let renderer = ImageRenderer(content: captureView)
            renderer.scale = 2
            guard let pngData = renderedPNGData(from: renderer) else {
                shareError = t("The chart image could not be rendered on this device.")
                return
            }

            do {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(payload.suggestedFilename)
                try pngData.write(to: url, options: .atomic)
                shareSheetPayload = InsightsRenderedSharePayload(
                    title: payload.title,
                    filename: payload.suggestedFilename,
                    url: url
                )
            } catch {
                shareError = error.localizedDescription
            }
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    @available(iOS 16.0, macOS 13.0, *)
    private func renderedPNGData<Content: View>(from renderer: ImageRenderer<Content>) -> Data? {
        #if os(iOS)
        return renderer.uiImage?.pngData()
        #elseif os(macOS)
        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
    #endif

    private func accentColor(for metric: InsightsTopDayMetric) -> Color {
        switch metric {
        case .events:
            return .orange
        case .visits:
            return .blue
        case .routes:
            return .green
        case .distance:
            return .purple
        }
    }

    private func accentColor(for metric: InsightsTrendMetric) -> Color {
        switch metric {
        case .distance:
            return .purple
        case .events:
            return .orange
        case .visits:
            return .blue
        case .routes:
            return .green
        }
    }

    private func weekdayAxisLabel(for metric: InsightsWeekdayMetric) -> String {
        switch metric {
        case .events:
            return t("Avg events")
        case .routes:
            return t("Avg routes")
        case .distance:
            return distanceAxisLabel(unit: preferences.distanceUnit)
        }
    }

    private func periodAxisLabel(for metric: InsightsPeriodMetric) -> String {
        switch metric {
        case .days:
            return t("Days")
        case .events:
            return t("Events")
        case .distance:
            return distanceAxisLabel(unit: preferences.distanceUnit)
        }
    }

    private func periodAccentColor(for metric: InsightsPeriodMetric) -> Color {
        switch metric {
        case .days:
            return .orange
        case .events:
            return .blue
        case .distance:
            return .purple
        }
    }

    private func axisLabel(for metric: InsightsTrendMetric) -> String {
        switch metric {
        case .distance:
            return preferences.distanceUnit.shortLabel
        case .events:
            return "Events"
        case .visits:
            return "Visits"
        case .routes:
            return "Routes"
        }
    }

    private func formatDuration(_ hours: Double) -> String {
        if hours < 1 {
            return preferences.appLanguage.isGerman ? String(format: "%.0f Min.", hours * 60) : String(format: "%.0f min", hours * 60)
        }
        let wholeHours = Int(hours)
        let remainingMinutes = Int((hours - Double(wholeHours)) * 60)
        return remainingMinutes > 0 ? "\(wholeHours)h \(remainingMinutes)m" : "\(wholeHours)h"
    }

    private func t(_ english: String) -> String {
        preferences.localized(english)
    }

    private var insightsChartDateFormatter: DateFormatter {
        Self.chartDateFormatter
    }

    private func dayCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Tag" : "Tage")"
            : "\(count) \(count == 1 ? "day" : "days")"
    }

    private func visitCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Besuch" : "Besuche")"
            : "\(count) \(count == 1 ? "visit" : "visits")"
    }

    private func activityCountText(_ count: Int) -> String {
        preferences.appLanguage.isGerman
            ? "\(count) \(count == 1 ? "Aktivität" : "Aktivitäten")"
            : "\(count) \(count == 1 ? "activity" : "activities")"
    }
}

private struct InsightsSummaryCard: Identifiable {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color

    var id: String { title }
}

private extension AppInsightsContentView {
    static let chartDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private struct InsightsRenderedSharePayload: Identifiable {
    let id = UUID()
    let title: String
    let filename: String
    let url: URL
}

private struct InsightsShareCaptureView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
            content
        }
        .padding(20)
        .frame(width: 860, alignment: .leading)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return .white
        #endif
    }
}

#endif
