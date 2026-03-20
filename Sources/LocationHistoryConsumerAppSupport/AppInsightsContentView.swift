#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer
#if canImport(Charts)
import Charts
#endif

// MARK: - Insights Content View

enum ActivityMetric: String, CaseIterable {
    case count = "Count"
    case distance = "Distance"
}

struct AppInsightsContentView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let insights: ExportInsights
    let daySummaries: [DaySummary]
    let onDayTap: ((String) -> Void)?
    @State private var activityMetric: ActivityMetric = .count

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(insights: ExportInsights, daySummaries: [DaySummary] = [], onDayTap: ((String) -> Void)? = nil) {
        self.insights = insights
        self.daySummaries = daySummaries
        self.onDayTap = onDayTap
    }

    private struct WeekdayStat: Identifiable {
        let id: Int
        let name: String
        let avgEvents: Double
    }

    private var weekdayStats: [WeekdayStat] {
        guard daySummaries.count >= 3 else { return [] }
        var buckets: [Int: (total: Int, count: Int)] = [:]
        for summary in daySummaries {
            guard let date = Self.chartDateFormatter.date(from: summary.date) else { continue }
            let wd = Calendar.current.component(.weekday, from: date)
            let events = summary.visitCount + summary.activityCount
            let b = buckets[wd] ?? (total: 0, count: 0)
            buckets[wd] = (total: b.total + events, count: b.count + 1)
        }
        // Mon(2)..Sat(7), Sun(1) last
        let order = [2, 3, 4, 5, 6, 7, 1]
        let names = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        return order.compactMap { wd in
            guard let b = buckets[wd], b.count > 0 else { return nil }
            return WeekdayStat(id: wd, name: names[wd]!, avgEvents: Double(b.total) / Double(b.count))
        }
    }

    private var hasDayData: Bool {
        !daySummaries.isEmpty
    }

    private var hasDistanceData: Bool {
        daySummaries.contains(where: { $0.totalPathDistanceM > 0 })
    }

    private var canShowDailyAverages: Bool {
        daySummaries.count >= 2
    }

    private var hasWeekdayData: Bool {
        !weekdayStats.isEmpty
    }

    private var shouldShowDenseDistanceAxis: Bool {
        daySummaries.count <= 12
    }

    private var activityMetricAxisLabel: String {
        activityMetric == .distance ? distanceAxisLabel(unit: preferences.distanceUnit) : "Activity Count"
    }

    private var hasAnyMeaningfulInsightSection: Bool {
        hasDistanceData ||
        canShowDailyAverages ||
        !insights.activityBreakdown.isEmpty ||
        !insights.visitTypeBreakdown.isEmpty ||
        hasWeekdayData ||
        !insights.periodBreakdown.isEmpty
    }

    var body: some View {
        if !hasDayData {
            pageEmptyState(
                title: "No Insights Yet",
                message: "This import contains no day entries, so there is nothing meaningful to analyze yet.",
                systemImage: "chart.line.text.clipboard"
            )
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !hasAnyMeaningfulInsightSection {
                    insightsEmptyCard(
                        title: "Limited Insight Data",
                        message: "The import loaded correctly, but it does not contain enough structured data for the current insight views yet.",
                        systemImage: "chart.bar.xaxis"
                    )
                }

                insightSection("Distance Over Time", icon: "chart.bar.fill") {
                    #if canImport(Charts)
                    if hasDistanceData {
                        distanceChart
                        if onDayTap != nil {
                            sectionHint("Tap a bar to open the corresponding day.", systemImage: "hand.tap")
                        }
                        Text("Route distances only")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        insightsEmptyCard(
                            title: "No Route Distances",
                            message: "This import does not contain route distance data that could be plotted over time.",
                            systemImage: "road.lanes"
                        )
                    }
                    #else
                    insightsEmptyCard(
                        title: "Charts Unavailable",
                        message: "This platform build does not include chart rendering for the distance timeline.",
                        systemImage: "chart.bar"
                    )
                    #endif
                }

                insightSection("Daily Averages", icon: "chart.bar.fill") {
                    if canShowDailyAverages {
                        let avg = insights.averagesPerDay
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            avgCard(String(format: "%.1f", avg.avgVisitsPerDay), label: "Visits / Day", icon: "mappin.and.ellipse", color: .blue)
                            avgCard(String(format: "%.1f", avg.avgActivitiesPerDay), label: "Activities / Day", icon: "figure.walk", color: .green)
                            avgCard(String(format: "%.1f", avg.avgPathsPerDay), label: "Routes / Day", icon: "location.north.line", color: .orange)
                            avgCard(formatDistance(avg.avgDistancePerDayM, unit: preferences.distanceUnit), label: "Distance / Day", icon: "road.lanes", color: .purple)
                        }
                    } else {
                        insightsEmptyCard(
                            title: "Need More Than One Day",
                            message: "Daily averages become meaningful once the import contains at least two different days.",
                            systemImage: "calendar.badge.plus"
                        )
                    }
                }

                insightSection("Activity Types", icon: "figure.walk") {
                    if !insights.activityBreakdown.isEmpty {
                        #if canImport(Charts)
                        Picker("", selection: $activityMetric) {
                            ForEach(ActivityMetric.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)
                        activityTypeChart
                        sectionHint("Compare activities by \(activityMetric == .distance ? "covered distance" : "entry count").")
                        #endif
                        ForEach(Array(insights.activityBreakdown.enumerated()), id: \.offset) { _, item in
                            activityBreakdownCard(item)
                        }
                    } else {
                        insightsEmptyCard(
                            title: "No Activity Breakdown",
                            message: "No activity entries were found that could be summarized by type, distance or duration.",
                            systemImage: "figure.walk.motion"
                        )
                    }
                }

                insightSection("Visit Types", icon: "mappin.and.ellipse") {
                    if !insights.visitTypeBreakdown.isEmpty {
                        #if canImport(Charts)
                        visitTypeChart
                        #endif
                        ForEach(Array(insights.visitTypeBreakdown.enumerated()), id: \.offset) { _, item in
                            visitTypeRow(item)
                        }
                    } else {
                        insightsEmptyCard(
                            title: "No Visit Types",
                            message: "This import does not contain visit data that can be grouped into semantic place types.",
                            systemImage: "mappin.slash"
                        )
                    }
                }

                insightSection("By Day of Week", icon: "chart.bar") {
                    #if canImport(Charts)
                    if hasWeekdayData {
                        weekdayChart
                        sectionHint("Average visit and activity events per weekday across the imported days.")
                    } else {
                        insightsEmptyCard(
                            title: "Need More Day Coverage",
                            message: "A weekday pattern is only shown once at least three separate day summaries are available.",
                            systemImage: "calendar"
                        )
                    }
                    #else
                    insightsEmptyCard(
                        title: "Charts Unavailable",
                        message: "This platform build does not include chart rendering for the weekday view.",
                        systemImage: "chart.bar"
                    )
                    #endif
                }

                insightSection("Period Breakdown", icon: "calendar.badge.clock") {
                    if !insights.periodBreakdown.isEmpty {
                        ForEach(Array(insights.periodBreakdown.enumerated()), id: \.offset) { _, item in
                            periodRow(item)
                        }
                    } else {
                        insightsEmptyCard(
                            title: "No Period Stats",
                            message: "This export does not include aggregated month or year period statistics.",
                            systemImage: "calendar.badge.exclamationmark"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
            content()
        }
    }

    @ViewBuilder
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

    @ViewBuilder
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func sectionHint(_ text: String, systemImage: String = "info.circle") -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func activityBreakdownCard(_ item: ActivityBreakdownItem) -> some View {
        let color = colorForActivityType(item.activityType)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForActivityType(item.activityType))
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(displayNameForActivityType(item.activityType))
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func visitTypeRow(_ item: VisitTypeItem) -> some View {
        HStack {
            Image(systemName: iconForVisitType(item.semanticType))
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(item.semanticType.capitalized)
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
    private func periodRow(_ item: PeriodBreakdownItem) -> some View {
        let periodColor = item.distanceM > 0 ? Color.purple : Color.secondary
        VStack(alignment: .leading, spacing: 6) {
            Text(item.label)
                .font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                Label("\(item.days) days", systemImage: "calendar")
                Label("\(item.visits) visits", systemImage: "mappin.and.ellipse")
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Charts

    #if canImport(Charts)
    @ViewBuilder
    private var distanceChart: some View {
        Chart {
            ForEach(daySummaries, id: \.date) { summary in
                if let date = Self.chartDateFormatter.date(from: summary.date) {
                    BarMark(
                        x: .value("Date", date, unit: .day),
                        y: .value(distanceAxisLabel(unit: preferences.distanceUnit), distanceValue(summary.totalPathDistanceM, unit: preferences.distanceUnit))
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                }
            }
        }
        .chartXAxis(shouldShowDenseDistanceAxis ? .automatic : .hidden)
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
                        guard let onDayTap else { return }
                        let x = location.x - geometry.frame(in: .local).minX
                        if let tappedDate: Date = proxy.value(atX: x) {
                            let iso = Self.chartDateFormatter.string(from: tappedDate)
                            if daySummaries.contains(where: { $0.date == iso }) {
                                onDayTap(iso)
                            }
                        }
                    }
            }
        }
        .frame(height: 150)
    }

    @ViewBuilder
    private var activityTypeChart: some View {
        let items = insights.activityBreakdown
        let hasDistance = items.contains(where: { $0.totalDistanceKM > 0 })
        let showDistance = activityMetric == .distance && hasDistance
        Chart {
            ForEach(items, id: \.activityType) { item in
                let xVal = showDistance ? distanceValue(item.totalDistanceKM * 1000, unit: preferences.distanceUnit) : Double(item.count)
                BarMark(
                    x: .value(showDistance ? distanceAxisLabel(unit: preferences.distanceUnit) : "Count", xVal),
                    y: .value("Type", item.activityType.capitalized)
                )
                .foregroundStyle(Color.green)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(showDistance ? String(format: "%.1f", distanceValue(item.totalDistanceKM * 1000, unit: preferences.distanceUnit)) : "\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartXAxisLabel(activityMetricAxisLabel, alignment: .trailing)
        .frame(height: CGFloat(max(items.count, 1)) * 40 + 8)
    }

    @ViewBuilder
    private var visitTypeChart: some View {
        let totalCount = insights.visitTypeBreakdown.reduce(0) { $0 + $1.count }
        if totalCount > 0 {
            Chart {
                ForEach(insights.visitTypeBreakdown, id: \.semanticType) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Type", item.semanticType.capitalized)
                    )
                    .foregroundStyle(Color.blue)
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
            .chartXAxisLabel("Visit Count", alignment: .trailing)
            .frame(height: CGFloat(max(insights.visitTypeBreakdown.count, 1)) * 40 + 8)
        }
    }

    @ViewBuilder
    private var weekdayChart: some View {
        Chart {
            ForEach(weekdayStats) { stat in
                BarMark(
                    x: .value("Day", stat.name),
                    y: .value("Avg", stat.avgEvents)
                )
                .foregroundStyle(Color.indigo)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", stat.avgEvents))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYAxisLabel("Avg events", alignment: .trailing)
        .frame(height: 110)
        .padding(.bottom, 2)
    }
    #endif

    private func formatDuration(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0f min", hours * 60)
        }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

#endif
