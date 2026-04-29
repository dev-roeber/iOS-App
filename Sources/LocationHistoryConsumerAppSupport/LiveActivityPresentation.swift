import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

public enum LiveActivityUploadState: String, Codable, CaseIterable, Hashable, Sendable {
    case disabled
    case active
    case pending
    case failed
    case paused

    public var localizedName: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .active:
            return "Active"
        case .pending:
            return "Pending"
        case .failed:
            return "Failed"
        case .paused:
            return "Paused"
        }
    }

    public var compactLabel: String {
        switch self {
        case .disabled:
            return "Off"
        case .active:
            return "On"
        case .pending:
            return "Queue"
        case .failed:
            return "Retry"
        case .paused:
            return "Pause"
        }
    }

    public var systemImageName: String {
        switch self {
        case .disabled:
            return "arrow.up.circle"
        case .active:
            return "arrow.up.circle.fill"
        case .pending:
            return "tray.full.fill"
        case .failed:
            return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .paused:
            return "pause.circle.fill"
        }
    }
}

public enum DynamicIslandCompactDisplay: String, Codable, CaseIterable {
    case distance
    case points
    case elapsed
    case uploadStatus

    public var localizedName: String {
        switch self {
        case .distance:
            return "Distance"
        case .points:
            return "Points"
        case .elapsed:
            return "Duration"
        case .uploadStatus:
            return "Upload Status"
        }
    }
}

public struct LiveActivityFeatureAvailability: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case available
        case disabled
        case unsupported
    }

    public let status: Status

    public init(status: Status) {
        self.status = status
    }

    public var isConfigurable: Bool {
        status == .available
    }

    public var statusLabel: String {
        switch status {
        case .available:
            return "Available"
        case .disabled:
            return "Disabled"
        case .unsupported:
            return "Unavailable"
        }
    }

    public var detailMessage: String {
        switch status {
        case .available:
            return "Live Activities are available for active recordings on this device."
        case .disabled:
            return "Live Activities are turned off in iOS Settings for this device."
        case .unsupported:
            return "Live Activities require iPhone with iOS 16.2 or later."
        }
    }

    public static func current() -> LiveActivityFeatureAvailability {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.2, *) {
            return LiveActivityFeatureAvailability(
                status: ActivityAuthorizationInfo().areActivitiesEnabled ? .available : .disabled
            )
        }
        return LiveActivityFeatureAvailability(status: .unsupported)
        #else
        return LiveActivityFeatureAvailability(status: .unsupported)
        #endif
    }
}

public struct LiveActivityValuePresentation: Equatable, Sendable {
    public let systemImageName: String
    public let text: String
    public let compactText: String
    public let accessibilityLabel: String
}

public enum LiveActivityValueFormatter {
    public static func presentation(
        for display: DynamicIslandCompactDisplay,
        status: TrackingStatus,
        startTime: Date,
        now: Date = Date()
    ) -> LiveActivityValuePresentation {
        switch display {
        case .distance:
            let value = status.formattedDistance
            return LiveActivityValuePresentation(
                systemImageName: "ruler",
                text: value,
                compactText: value,
                accessibilityLabel: "Distance \(value)"
            )
        case .points:
            let value = "\(max(0, status.pointCount))"
            return LiveActivityValuePresentation(
                systemImageName: "point.topleft.down.curvedto.point.bottomright.up",
                text: value,
                compactText: value,
                accessibilityLabel: value == "1" ? "1 point" : "\(value) points"
            )
        case .elapsed:
            let value = formattedElapsed(since: startTime, now: now)
            return LiveActivityValuePresentation(
                systemImageName: "timer",
                text: value,
                compactText: value,
                accessibilityLabel: "Duration \(value)"
            )
        case .uploadStatus:
            let value = status.uploadState
            return LiveActivityValuePresentation(
                systemImageName: value.systemImageName,
                text: value.localizedName,
                compactText: value.compactLabel,
                accessibilityLabel: "Upload status \(value.localizedName)"
            )
        }
    }

    public static func formattedElapsed(since startTime: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(startTime)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }
}
