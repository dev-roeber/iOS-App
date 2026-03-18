#if canImport(SwiftUI)
import SwiftUI
import LocationHistoryConsumer

// MARK: - Date Formatting

enum AppDateDisplay {
    // en_US_POSIX locale is required so that the fixed "yyyy-MM-dd" format is
    // interpreted literally, regardless of the device's regional settings.
    // Without it, DateFormatter may silently rearrange the format on some locales.
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func longDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return d.formatted(date: .long, time: .omitted)
    }

    static func mediumDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    static func weekday(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return d.formatted(.dateTime.weekday(.wide))
    }

    static func monthYear(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return String(iso.prefix(7)) }
        return d.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Time Formatting

enum AppTimeDisplay {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    static func time(_ iso8601: String) -> String {
        guard let date = isoFormatter.date(from: iso8601) else { return iso8601 }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Card Accent Colors

enum CardAccent {
    static let visit = Color.blue
    static let activity = Color.green
    static let path = Color.orange
}

// MARK: - Distance Formatting

func formatDistance(_ meters: Double) -> String {
    guard meters >= 0, meters.isFinite else { return "–" }
    let measurement = Measurement(value: meters, unit: UnitLength.meters)
    return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
}

// MARK: - Month Grouping

struct MonthGroup: Identifiable {
    let key: String
    let title: String
    let summaries: [DaySummary]
    var id: String { key }
}

func groupByMonth(_ summaries: [DaySummary]) -> [MonthGroup] {
    var groups: [(key: String, summaries: [DaySummary])] = []
    var currentKey: String?
    var currentSummaries: [DaySummary] = []

    for summary in summaries {
        let key = String(summary.date.prefix(7))
        if key != currentKey {
            if let prevKey = currentKey {
                groups.append((key: prevKey, summaries: currentSummaries))
            }
            currentKey = key
            currentSummaries = [summary]
        } else {
            currentSummaries.append(summary)
        }
    }
    if let prevKey = currentKey {
        groups.append((key: prevKey, summaries: currentSummaries))
    }

    return groups.map { group in
        MonthGroup(
            key: group.key,
            title: AppDateDisplay.monthYear(group.summaries[0].date),
            summaries: group.summaries
        )
    }
}

// MARK: - Colored Card Helper

@ViewBuilder
func coloredCard<Content: View>(
    color: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 0) {
        color
            .frame(width: 4)
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.06))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    // Combine children so VoiceOver reads the whole card as one item.
    .accessibilityElement(children: .combine)
}

// MARK: - Icon Helpers

func iconForVisitType(_ type: String?) -> String {
    switch (type ?? "").uppercased() {
    case "HOME": return "house.fill"
    case "WORK": return "briefcase.fill"
    case "CAFE": return "cup.and.saucer.fill"
    case "PARK": return "leaf.fill"
    case "LEISURE": return "gamecontroller.fill"
    case "EVENT": return "star.fill"
    case "STAY": return "bed.double.fill"
    default: return "mappin"
    }
}

func iconForActivityType(_ type: String?) -> String {
    switch (type ?? "").uppercased() {
    case "WALKING": return "figure.walk"
    case "CYCLING": return "bicycle"
    case "IN PASSENGER VEHICLE": return "car.fill"
    case "IN BUS": return "bus.fill"
    case "RUNNING": return "figure.run"
    case "IN TRAIN": return "train.side.front.car"
    case "IN SUBWAY": return "tram.fill"
    case "FLYING": return "airplane"
    default: return "figure.walk"
    }
}

func colorForActivityType(_ type: String?) -> Color {
    switch (type ?? "").uppercased() {
    case "WALKING":              return .green
    case "RUNNING":              return .orange
    case "CYCLING":              return .blue
    case "FLYING":               return .purple
    case "IN PASSENGER VEHICLE": return .red
    case "IN BUS":               return .teal
    case "IN TRAIN":             return .indigo
    case "IN SUBWAY":            return .indigo
    default:                     return .gray
    }
}

func displayNameForActivityType(_ type: String?, default defaultName: String = "Activity") -> String {
    switch (type ?? "").uppercased() {
    case "WALKING":              return "Walking"
    case "CYCLING":              return "Cycling"
    case "RUNNING":              return "Running"
    case "FLYING":               return "Flying"
    case "IN PASSENGER VEHICLE": return "Car"
    case "IN BUS":               return "Bus"
    case "IN TRAIN":             return "Train"
    case "IN SUBWAY":            return "Subway"
    default:
        guard let type else { return defaultName }
        return type.capitalized
    }
}

#endif
