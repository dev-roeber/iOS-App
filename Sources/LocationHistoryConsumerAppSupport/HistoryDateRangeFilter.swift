import Foundation

/// Preset time ranges for filtering the visible location history.
public enum HistoryDateRangePreset: String, Identifiable, CaseIterable, Equatable {
    case rollingWindow = "rollingWindow"
    case last7Days = "last7Days"
    case last30Days = "last30Days"
    case last90Days = "last90Days"
    case thisYear = "thisYear"
    case custom = "custom"
    case all = "all"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All Time"
        case .rollingWindow: return "60-Day Window"
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
        case .rollingWindow: return "60 d"
        case .last7Days: return "7 d"
        case .last30Days: return "30 d"
        case .last90Days: return "90 d"
        case .thisYear: return "Year"
        case .custom: return "Custom"
        }
    }

    /// Computes the effective date range for this preset relative to `now`.
    /// Returns `nil` for `.all`, `.custom` and `.rollingWindow` — callers must
    /// supply custom bounds (rollingWindow uses dataset bounds + offset).
    public func computedRange(relativeTo now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        switch self {
        case .all, .custom, .rollingWindow:
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
    /// Default size in days of the rolling window used as standard view on
    /// fresh imports. Caps memory and rendering load while still surfacing a
    /// meaningful slice of recent data.
    public static let defaultRollingWindowSize: Int = 60

    public var preset: HistoryDateRangePreset
    public var customStart: Date?
    public var customEnd: Date?
    /// Size of the rolling window (in days). Only relevant for
    /// `.rollingWindow` preset. Defaults to 60.
    public var rollingWindowSize: Int
    /// Offset of the rolling window's end from the dataset's end date, in
    /// days. `0` means the window ends at `datasetEndDate`. Positive values
    /// move the window further into the past. Always clamped to a valid range
    /// by `computedRollingWindowRange()`.
    public var rollingWindowOffset: Int
    /// Start date of the imported dataset (oldest day). Used to clamp the
    /// rolling window slider so it cannot slide beyond available data.
    public var datasetStartDate: Date?
    /// End date of the imported dataset (newest day). Used as the anchor for
    /// the rolling window at offset `0`.
    public var datasetEndDate: Date?

    public static let `default` = HistoryDateRangeFilter(preset: .all)

    public init(
        preset: HistoryDateRangePreset = .all,
        customStart: Date? = nil,
        customEnd: Date? = nil,
        rollingWindowSize: Int = HistoryDateRangeFilter.defaultRollingWindowSize,
        rollingWindowOffset: Int = 0,
        datasetStartDate: Date? = nil,
        datasetEndDate: Date? = nil
    ) {
        self.preset = preset
        self.customStart = customStart
        self.customEnd = customEnd
        self.rollingWindowSize = max(1, rollingWindowSize)
        self.rollingWindowOffset = max(0, rollingWindowOffset)
        self.datasetStartDate = datasetStartDate
        self.datasetEndDate = datasetEndDate
    }

    /// Whether this filter actively restricts the visible data.
    public var isActive: Bool {
        preset != .all
    }

    /// Maximum valid offset value for the rolling window slider. Returns `0`
    /// when the dataset is smaller than or equal to the window size — in that
    /// case the slider should be disabled because there is nothing to scroll.
    public var maxRollingWindowOffset: Int {
        guard let start = datasetStartDate, let end = datasetEndDate, start <= end else {
            return 0
        }
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)
        ).day ?? 0
        // totalDays is "gaps between days", we want inclusive count of days:
        let inclusiveDayCount = totalDays + 1
        return max(0, inclusiveDayCount - rollingWindowSize)
    }

    /// Computes the effective rolling-window range from the current offset,
    /// window size and dataset bounds. Returns `nil` when dataset bounds are
    /// unknown.
    public func computedRollingWindowRange(calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard let datasetStart = datasetStartDate, let datasetEnd = datasetEndDate,
              datasetStart <= datasetEnd else {
            return nil
        }
        let endOfData = calendar.startOfDay(for: datasetEnd)
        let startOfData = calendar.startOfDay(for: datasetStart)
        let clampedOffset = min(max(0, rollingWindowOffset), maxRollingWindowOffset)
        let windowEnd = calendar.date(byAdding: .day, value: -clampedOffset, to: endOfData) ?? endOfData
        let proposedStart = calendar.date(byAdding: .day, value: -(rollingWindowSize - 1), to: windowEnd) ?? windowEnd
        let windowStart = max(proposedStart, startOfData)
        // Stretch the end to fill the whole UTC day so date-string comparisons
        // include the last day completely.
        let dayBumped = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: windowEnd) ?? windowEnd
        return windowStart...dayBumped
    }

    /// The effective date range, or `nil` when all data should be shown.
    public var effectiveRange: ClosedRange<Date>? {
        switch preset {
        case .all:
            return nil
        case .custom:
            guard let start = customStart, let end = customEnd, start <= end else { return nil }
            return start...end
        case .rollingWindow:
            return computedRollingWindowRange()
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
        localizedChipLabel { $0 }
    }

    /// Localized variant of `chipLabel`. Pass an injected closure (typically
    /// `preferences.localized`) so the chip text follows the active app
    /// language without coupling this Foundation-only filter to AppSupport.
    public func localizedChipLabel(_ localize: (String) -> String) -> String {
        switch preset {
        case .all: return localize("All Time")
        case .rollingWindow:
            return localize("60-Day Window")
        case .last7Days: return localize("Last 7 days")
        case .last30Days: return localize("Last 30 days")
        case .last90Days: return localize("Last 90 days")
        case .thisYear:
            let year = Calendar.current.component(.year, from: Date())
            return "\(year)"
        case .custom:
            guard let start = customStart, let end = customEnd else { return localize("Custom") }
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
        rollingWindowOffset = 0
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
