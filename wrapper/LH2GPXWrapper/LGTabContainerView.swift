import SwiftUI
import LocationHistoryConsumer
import LocationHistoryConsumerAppSupport

@available(iOS 26.0, *)
struct LGTabContainerView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var session: AppSessionState
    @ObservedObject var liveLocation: LiveLocationFeatureModel
    let onOpen: () -> Void
    let onLoadDemo: () -> Void
    let onClear: () -> Void

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedDate: String?
    @State private var dayListFilter = DayListFilter.empty

    private var summaries: [DaySummary] {
        session.content?.daySummaries(applying: nil) ?? session.daySummaries
    }

    private var filteredSummaries: [DaySummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return summaries }
        return summaries.filter { summary in
            summary.date.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Karte", systemImage: "map", value: 0) {
                NavigationStack {
                    AppOverviewView(
                        overview: session.content?.overview(applying: nil) ?? session.overview,
                        insights: session.content?.insights(applying: nil) ?? session.insights,
                        onOpen: onOpen,
                        onLoadDemo: onLoadDemo,
                        onClear: onClear
                    )
                    .navigationTitle("Karte")
                }
            }

            Tab("Tage", systemImage: "calendar", value: 1) {
                NavigationStack {
                    AppDayListView(
                        summaries: filteredSummaries,
                        selectedForExportDates: session.exportSelection.selectedDates,
                        selectedDate: Binding(
                            get: { selectedDate ?? session.selectedDate },
                            set: { selectedDate = $0 }
                        ),
                        filter: $dayListFilter,
                        searchText: $searchText
                    )
                    .navigationTitle("Tage")
                }
            }

            Tab("Live", systemImage: "record.circle", value: 2) {
                NavigationStack {
                    AppLiveTrackingView(liveLocation: liveLocation)
                        .navigationTitle("Live")
                }
            }

            Tab("Insights", systemImage: "chart.xyaxis.line", value: 3) {
                NavigationStack {
                    AppInsightsView(insights: session.content?.insights(applying: nil) ?? session.insights)
                        .navigationTitle("Insights")
                }
            }

            Tab("Suche", systemImage: "magnifyingglass", value: 4, role: .search) {
                NavigationStack {
                    AppSearchView(summaries: filteredSummaries, searchText: $searchText)
                        .navigationTitle("Suche")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Tage, Datum oder Monat suchen")
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if liveLocation.isRecording {
                LiveRecordingAccessory(liveModel: liveLocation) {
                    selectedTab = 2
                }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct LiveRecordingAccessory: View {
    @ObservedObject var liveModel: LiveLocationFeatureModel
    let onOpenLiveTab: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, options: .repeating, value: liveModel.isRecording)
            Text("Aufnahme läuft")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(String(format: "%.2f km", liveModel.currentDistanceMeters / 1000))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                onOpenLiveTab()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .accessibilityLabel("Live-Aufnahme öffnen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

@available(iOS 26.0, *)
private struct AppOverviewView: View {
    let overview: ExportOverview?
    let insights: ExportInsights?
    let onOpen: () -> Void
    let onLoadDemo: () -> Void
    let onClear: () -> Void

    var body: some View {
        List {
            Section {
                metricRow("Tage", value: overview.map { "\($0.dayCount)" } ?? "-")
                metricRow("Routen", value: overview.map { "\($0.totalPathCount)" } ?? "-")
                metricRow("Orte", value: overview.map { "\($0.totalVisitCount)" } ?? "-")
                metricRow("Distanz", value: insights.map { String(format: "%.1f km", $0.totalDistanceM / 1000) } ?? "-")
            }
            Section {
                Button("Datei importieren", action: onOpen)
                Button("Demo laden", action: onLoadDemo)
                Button("Aktuelle Daten löschen", role: .destructive, action: onClear)
            }
        }
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}

@available(iOS 26.0, *)
private struct AppInsightsView: View {
    let insights: ExportInsights?

    var body: some View {
        List {
            if let insights {
                Section {
                    metricRow("Gesamtdistanz", value: String(format: "%.1f km", insights.totalDistanceM / 1000))
                    metricRow("Besuche/Tag", value: String(format: "%.1f", insights.averagesPerDay.avgVisitsPerDay))
                    metricRow("Routen/Tag", value: String(format: "%.1f", insights.averagesPerDay.avgPathsPerDay))
                }
                if let longest = insights.longestDistanceDay {
                    Section("Top-Tag") {
                        metricRow(longest.date, value: longest.value)
                    }
                }
            } else {
                ContentUnavailableView("Keine Insights", systemImage: "chart.xyaxis.line")
            }
        }
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}

@available(iOS 26.0, *)
private struct AppSearchView: View {
    let summaries: [DaySummary]
    @Binding var searchText: String

    var body: some View {
        List(summaries, id: \.date) { summary in
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.date)
                    .font(.headline)
                Text("\(summary.pathCount) Routen · \(summary.visitCount) Orte · \(String(format: "%.1f km", summary.totalPathDistanceM / 1000))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if summaries.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Keine Tage" : "Keine Treffer",
                    systemImage: "magnifyingglass"
                )
            }
        }
    }
}
