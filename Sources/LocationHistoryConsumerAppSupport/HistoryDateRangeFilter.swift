import Foundation

/// Preset time ranges for filtering the visible location history.
public enum HistoryDateRangePreset: String, Identifiable, CaseIterable, Equatable {
    case all = "all"
    case last7Days = "last7Days"
    case last30Days = "last30Days"
    case last90Days = "last90Days"
    case thisYear = "thisYear"
    case custom = "custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All Time"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .thisYear: return "This Year"
        case .custom: return "Custom Range"
        }
    }

    public var shortLabel: String {
        switch self {
        case .all: return "All"
        case .last7Days: return "7 d"
        case .last30Days: return "30 d"
        case .last90Days: return "90 d"
        case .thisYear: return "Year"
        case .custom: return "Custom"
        }
    }

    /// Computes the effective date range for this preset relative to `now`.
    /// Returns `nil` for `.all` and `.custom` (caller must supply custom bounds).
    public func computedRange(relativeTo now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        switch self {
        case .all, .custom:
            return nil
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            return start...now
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            return start...now
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))!
            return start...now
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            let start = calendar.date(from: comps)!
            return start...now
        }
    }
}

/// Validates custom date range inputs.
public enum HistoryDateRangeValidator {
    private static let maxRangeYears: Int = 10

    public enum ValidationResult: Equatable {
        case valid
        case startAfterEnd
        case tooWide
        case startTooFarInPast
    }

    public static func validate(start: Date, end: Date, relativeTo now: Date = Date()) -> ValidationResult {
        guard start <= end else { return .startAfterEnd }

        let calendar = Calendar.current
        let earliest = calendar.date(byAdding: .year, value: -maxRangeYears, to: now)!
        guard start >= earliest else { return .startTooFarInPast }

        let components = calendar.dateComponents([.year], from: start, to: end)
        if let years = components.year, years >= maxRangeYears { return .tooWide }

        return .valid
    }
}

/// App-wide date range filter state. Shared across Days, Insights, and Export tabs.
public struct HistoryDateRangeFilter: Equatable {
    public var preset: HistoryDateRangePreset
    public var customStart: Date?
    public var customEnd: Date?

    public static let `default` = HistoryDateRangeFilter(preset: .all)

    public init(preset: HistoryDateRangePreset = .all, customStart: Date? = nil, customEnd: Date? = nil) {
        self.preset = preset
        self.customStart = customStart
        self.customEnd = customEnd
    }

    /// Whether this filter actively restricts the visible data.
    public var isActive: Bool {
        preset != .all
    }

    /// The effective date range, or `nil` when all data should be shown.
    public var effectiveRange: ClosedRange<Date>? {
        switch preset {
        case .all:
            return nil
        case .custom:
            guard let start = customStart, let end = customEnd, start <= end else { return nil }
            return start...end
        default:
            return preset.computedRange()
        }
    }

    /// An ISO-8601 from-date string suitable for use in `AppExportQueryFilter`.
    public var fromDateString: String? {
        guard let range = effectiveRange else { return nil }
        return isoFormatter.string(from: range.lowerBound)
    }

    /// An ISO-8601 to-date string suitable for use in `AppExportQueryFilter`.
    public var toDateString: String? {
        guard let range = effectiveRange else { return nil }
        return isoFormatter.string(from: range.upperBound)
    }

    /// A short human-readable description of the active filter.
    public var chipLabel: String {
        switch preset {
        case .all: return "All Time"
        case .last7Days: return "Last 7 days"
        case .last30Days: return "Last 30 days"
        case .last90Days: return "Last 90 days"
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)"
        case .custom:
            guard let start = customStart, let end = customEnd else { return "Custom" }
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .none
            return "\(f.string(from: start)) – \(f.string(from: end))"
        }
    }

    public mutating func reset() {
        preset = .all
        customStart = nil
        customEnd = nil
    }

    private var isoFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        // Use the device's current timezone so that preset date boundaries
        // (computed in Calendar.current / local time) are not shifted to the
        // previous or next UTC day when the user is not in UTC. (task-7 fix)
        f.timeZone = .autoupdatingCurrent
        return f
    }
}
