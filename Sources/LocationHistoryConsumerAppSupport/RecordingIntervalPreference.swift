import Foundation

// MARK: - Unit

public enum RecordingIntervalUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case seconds
    case minutes
    case hours

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    /// Singular display name used when value == 1 (e.g. "Second", "Minute", "Hour").
    public var singularDisplayName: String {
        switch self {
        case .seconds: return "Second"
        case .minutes: return "Minute"
        case .hours:   return "Hour"
        }
    }

    /// Lowercase singular key for localisation lookups (e.g. "second", "minute", "hour").
    public var singularKey: String {
        switch self {
        case .seconds: return "second"
        case .minutes: return "minute"
        case .hours:   return "hour"
        }
    }

    public var maximumValue: Int {
        switch self {
        case .seconds: return 3600
        case .minutes: return 60
        case .hours: return 24
        }
    }
}

// MARK: - Preference

public struct RecordingIntervalPreference: Codable, Equatable, Sendable {
    public let unit: RecordingIntervalUnit
    public let value: Int

    /// 5 seconds – matches the rough cadence of a balanced live recording session.
    public static let `default` = RecordingIntervalPreference(value: 5, unit: .seconds)

    public init(value: Int, unit: RecordingIntervalUnit) {
        self.value = value
        self.unit = unit
    }

    /// Returns a clamped, valid instance. Out-of-range values are clipped to the
    /// unit's allowed range (seconds: 1–3600, minutes: 1–60, hours: 1–24).
    public static func validated(value: Int, unit: RecordingIntervalUnit) -> RecordingIntervalPreference {
        let clamped: Int
        switch unit {
        case .seconds: clamped = max(1, min(3600, value))
        case .minutes: clamped = max(1, min(60, value))
        case .hours:   clamped = max(1, min(24, value))
        }
        return RecordingIntervalPreference(value: clamped, unit: unit)
    }

    /// Total interval expressed in seconds.
    public var totalSeconds: TimeInterval {
        switch unit {
        case .seconds: return TimeInterval(value)
        case .minutes: return TimeInterval(value) * 60
        case .hours:   return TimeInterval(value) * 3600
        }
    }

    /// Plain English display string for the interval, e.g. "5 seconds", "1 minute".
    /// For a localised variant, build the string from `value` and a localised `unit.singularKey`/`unit.rawValue`.
    public var displayString: String {
        switch unit {
        case .seconds: return value == 1 ? "1 second"  : "\(value) seconds"
        case .minutes: return value == 1 ? "1 minute"  : "\(value) minutes"
        case .hours:   return value == 1 ? "1 hour"    : "\(value) hours"
        }
    }
}
