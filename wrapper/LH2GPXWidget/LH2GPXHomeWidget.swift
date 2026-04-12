#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI

private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17, *) {
            containerBackground(Color(UIColor.systemBackground), for: .widget)
        } else {
            background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Timeline Entry

struct LH2GPXEntry: TimelineEntry {
    let date: Date
    let lastRecording: WidgetDataStore.LastRecording?
    let weeklyStats: (km: Double, routes: Int)?
}

// MARK: - Provider

struct LH2GPXProvider: TimelineProvider {
    func placeholder(in context: Context) -> LH2GPXEntry {
        LH2GPXEntry(
            date: Date(),
            lastRecording: .init(date: Date(), distanceMeters: 5230, durationSeconds: 1800, trackName: "Morgenrunde"),
            weeklyStats: (km: 24.5, routes: 7)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LH2GPXEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LH2GPXEntry>) -> Void) {
        let e = entry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [e], policy: .after(nextUpdate)))
    }

    private func entry() -> LH2GPXEntry {
        LH2GPXEntry(
            date: Date(),
            lastRecording: WidgetDataStore.loadLastRecording(),
            weeklyStats: WidgetDataStore.loadWeeklyStats().map { ($0.km, $0.routes) }
        )
    }
}

// MARK: - Small Widget View

struct LH2GPXSmallWidgetView: View {
    let entry: LH2GPXEntry

    var body: some View {
        if let rec = entry.lastRecording {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(Color.accentColor)
                    Text("LH2GPX")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(rec.formattedDistance)
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.7)
                Text(rec.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rec.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetBackground()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("Keine Aufzeichnung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetBackground()
        }
    }
}

// MARK: - Medium Widget View

struct LH2GPXMediumWidgetView: View {
    let entry: LH2GPXEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: last recording
            VStack(alignment: .leading, spacing: 6) {
                Label("Letzte Tour", systemImage: "figure.walk")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let rec = entry.lastRecording {
                    Text(rec.formattedDistance)
                        .font(.title3.weight(.bold))
                        .minimumScaleFactor(0.7)
                    Text(rec.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rec.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("—")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()
                .padding(.vertical, 12)

            // Right: weekly stats
            VStack(alignment: .leading, spacing: 6) {
                Label("Diese Woche", systemImage: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let stats = entry.weeklyStats {
                    Text(String(format: "%.1f km", stats.km))
                        .font(.title3.weight(.bold))
                        .minimumScaleFactor(0.7)
                    Text("\(stats.routes) \(stats.routes == 1 ? "Tour" : "Touren")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine Daten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground()
    }
}

// MARK: - Widget Definition

@available(iOS 16.0, *)
struct LH2GPXHomeWidget: Widget {
    let kind: String = "LH2GPXHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LH2GPXProvider()) { entry in
            LH2GPXMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("LH2GPX")
        .description("Letzte Aufzeichnung und Wochenstats.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif
