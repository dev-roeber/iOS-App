import Foundation
import LocationHistoryConsumer
#if canImport(SwiftUI)
import SwiftUI
#endif

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

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let abbreviatedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let abbreviatedDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // NOTE: Static formatters use the device locale by default, not the app language.
    // The weekday and monthYear formatters are most impactful since they produce
    // day-of-week and month names in the device language rather than the app language.
    // Use weekday(_:locale:) and monthYear(_:locale:) overloads for localized output.
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    static func longDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return longDate(d)
    }

    static func mediumDate(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return mediumDate(d)
    }

    static func weekday(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return weekday(d)
    }

    static func weekday(_ iso: String, locale: Locale) -> String {
        guard let d = isoFormatter.date(from: iso) else { return iso }
        return weekday(d, locale: locale)
    }

    static func monthYear(_ iso: String) -> String {
        guard let d = isoFormatter.date(from: iso) else { return String(iso.prefix(7)) }
        return monthYear(d)
    }

    static func monthYear(_ iso: String, locale: Locale) -> String {
        guard let d = isoFormatter.date(from: iso) else { return String(iso.prefix(7)) }
        return monthYear(d, locale: locale)
    }

    static func longDate(_ date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    static func mediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    static func abbreviatedDate(_ date: Date) -> String {
        abbreviatedDateFormatter.string(from: date)
    }

    static func abbreviatedDateTime(_ date: Date) -> String {
        abbreviatedDateTimeFormatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    static func weekday(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func monthYear(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: date)
    }
}

// MARK: - Time Formatting

enum AppTimeDisplay {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func date(_ iso8601: String) -> Date? {
        fractionalFormatter.date(from: iso8601) ?? isoFormatter.date(from: iso8601)
    }

    static func time(_ iso8601: String) -> String {
        guard let date = date(iso8601) else { return iso8601 }
        return time(date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func timeRange(start: String?, end: String?) -> String? {
        guard let startDate = start.flatMap(date(_:)),
              let endDate = end.flatMap(date(_:)),
              endDate >= startDate else {
            return nil
        }

        return "\(time(startDate)) – \(time(endDate))"
    }

    static func timeRange(start: Date?, end: Date?) -> String? {
        guard let start,
              let end,
              end >= start else {
            return nil
        }

        return "\(time(start)) – \(time(end))"
    }

    static func duration(start: String?, end: String?) -> String? {
        guard let startDate = start.flatMap(date(_:)),
              let endDate = end.flatMap(date(_:)),
              endDate >= startDate else {
            return nil
        }

        return duration(endDate.timeIntervalSince(startDate))
    }

    static func duration(start: Date?, end: Date?) -> String? {
        guard let start,
              let end,
              end >= start else {
            return nil
        }

        return duration(end.timeIntervalSince(start))
    }

    static func duration(_ interval: TimeInterval) -> String? {
        guard interval.isFinite, interval >= 0 else {
            return nil
        }

        let totalMinutes = Int((interval / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours) h \(minutes) min"
        }
        return "\(minutes) min"
    }
}

// MARK: - Distance Formatting

func formatDistance(_ meters: Double, unit: AppDistanceUnitPreference = .metric) -> String {
    guard meters >= 0, meters.isFinite else { return "–" }
    switch unit {
    case .metric:
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    case .imperial:
        let miles = meters * 0.000_621_371
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        let feet = meters * 3.28084
        return "\(Int(feet.rounded())) ft"
    }
}

func distanceValue(_ meters: Double, unit: AppDistanceUnitPreference) -> Double {
    switch unit {
    case .metric:
        return meters / 1000
    case .imperial:
        return meters * 0.000_621_371
    }
}

func distanceAxisLabel(unit: AppDistanceUnitPreference) -> String {
    unit.shortLabel
}

func formatSpeed(_ kilometersPerHour: Double, unit: AppDistanceUnitPreference) -> String {
    guard kilometersPerHour >= 0, kilometersPerHour.isFinite else { return "–" }
    switch unit {
    case .metric:
        return String(format: "%.1f km/h", kilometersPerHour)
    case .imperial:
        return String(format: "%.1f mph", kilometersPerHour * 0.621_371)
    }
}

// MARK: - Month Grouping

struct MonthGroup: Identifiable {
    let key: String
    let title: String
    let summaries: [DaySummary]
    var id: String { key }
}

func groupByMonth(_ summaries: [DaySummary], locale: Locale = .autoupdatingCurrent) -> [MonthGroup] {
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
            title: AppDateDisplay.monthYear(group.summaries[0].date, locale: locale),
            summaries: group.summaries
        )
    }
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

func displayNameForVisitType(_ type: String?, default defaultName: String = "Unknown Place", language: AppLanguagePreference = .english) -> String {
    if language.isGerman {
        switch (type ?? "").uppercased() {
        case "HOME": return "Zuhause"
        case "WORK": return "Arbeit"
        case "CAFE": return "Café"
        case "RESTAURANT": return "Restaurant"
        case "PARK": return "Park"
        case "GYM", "LEISURE": return "Fitnessstudio"
        case "HOTEL", "STAY": return "Hotel"
        case "EVENT": return "Event"
        case "UNKNOWN", "": return defaultName
        default:
            guard let type, !type.isEmpty else { return defaultName }
            return type.capitalized
        }
    }
    switch (type ?? "").uppercased() {
    case "HOME": return "Home"
    case "WORK": return "Work"
    case "CAFE": return "Cafe"
    case "RESTAURANT": return "Restaurant"
    case "PARK": return "Park"
    case "GYM", "LEISURE": return "Gym"
    case "HOTEL", "STAY": return "Hotel"
    case "EVENT": return "Event"
    case "UNKNOWN", "": return defaultName
    default:
        guard let type, !type.isEmpty else { return defaultName }
        return type.capitalized
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

func displayNameForActivityType(_ type: String?, default defaultName: String = "Activity", language: AppLanguagePreference = .english) -> String {
    if language.isGerman {
        switch (type ?? "").uppercased() {
        case "WALKING":                         return "Zu Fuß"
        case "RUNNING":                         return "Laufen"
        case "CYCLING":                         return "Fahrrad"
        case "IN PASSENGER VEHICLE", "IN_VEHICLE": return "Auto"
        case "FLYING":                          return "Flug"
        case "IN BUS", "IN_BUS":               return "Bus"
        case "IN SUBWAY", "IN_SUBWAY":          return "U-Bahn"
        case "IN TRAIN", "IN_TRAIN":            return "Zug"
        case "IN TRAM", "IN_TRAM":             return "Straßenbahn"
        case "MOTORCYCLING":                    return "Motorrad"
        case "SKIING":                          return "Ski"
        default:
            guard let type else { return "Aktivität" }
            return type.capitalized
        }
    }
    switch (type ?? "").uppercased() {
    case "WALKING":              return "Walking"
    case "CYCLING":              return "Cycling"
    case "RUNNING":              return "Running"
    case "FLYING":               return "Flying"
    case "IN PASSENGER VEHICLE", "IN_VEHICLE": return "Car"
    case "IN BUS", "IN_BUS":    return "Bus"
    case "IN TRAIN", "IN_TRAIN": return "Train"
    case "IN SUBWAY", "IN_SUBWAY": return "Subway"
    case "IN TRAM", "IN_TRAM":  return "Tram"
    case "MOTORCYCLING":         return "Motorcycling"
    case "SKIING":               return "Skiing"
    default:
        guard let type else { return defaultName }
        return type.capitalized
    }
}

#if canImport(SwiftUI)
// MARK: - Card Accent Colors

enum CardAccent {
    static let visit = Color.blue
    static let activity = Color.green
    static let path = Color.orange
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
    .accessibilityElement(children: .combine)
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
#endif
