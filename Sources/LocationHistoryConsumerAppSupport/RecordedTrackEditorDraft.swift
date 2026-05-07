import Foundation
import LocationHistoryConsumer

public struct RecordedTrackEditorDraft: Equatable {
    public let originalTrack: RecordedTrack
    public var points: [RecordedTrackPoint]

    private let calendar: Calendar

    public init(track: RecordedTrack, calendar: Calendar = .autoupdatingCurrent) {
        self.originalTrack = track
        self.points = track.points
        self.calendar = calendar
    }

    public var isModified: Bool {
        points != originalTrack.points
    }

    public var validationMessage: String? {
        if points.count < 2 {
            return "A saved track needs at least 2 points."
        }

        for pair in zip(points, points.dropFirst()) {
            if pair.1.timestamp <= pair.0.timestamp {
                return "Point timestamps must stay in ascending order."
            }
        }

        return nil
    }

    public var distanceM: Double {
        totalDistance(points: points)
    }

    public var pointCount: Int {
        points.count
    }

    public var dayKey: String {
        guard let first = points.first else {
            return originalTrack.dayKey
        }
        return dayFormatter.string(from: first.timestamp)
    }

    public var startedAt: Date {
        points.first?.timestamp ?? originalTrack.startedAt
    }

    public var endedAt: Date {
        points.last?.timestamp ?? originalTrack.endedAt
    }

    public var savedTrack: RecordedTrack? {
        guard validationMessage == nil else {
            return nil
        }

        return RecordedTrack(
            id: originalTrack.id,
            startedAt: startedAt,
            endedAt: endedAt,
            dayKey: dayKey,
            distanceM: distanceM,
            captureMode: originalTrack.captureMode,
            points: points
        )
    }

    public mutating func reset() {
        points = originalTrack.points
    }

    public mutating func updateCoordinate(
        at index: Int,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        guard points.indices.contains(index) else {
            return
        }

        let existing = points[index]
        points[index] = RecordedTrackPoint(
            latitude: latitude ?? existing.latitude,
            longitude: longitude ?? existing.longitude,
            timestamp: existing.timestamp,
            horizontalAccuracyM: existing.horizontalAccuracyM
        )
    }

    public mutating func updateAccuracy(at index: Int, horizontalAccuracyM: Double) {
        guard points.indices.contains(index) else {
            return
        }

        let existing = points[index]
        points[index] = RecordedTrackPoint(
            latitude: existing.latitude,
            longitude: existing.longitude,
            timestamp: existing.timestamp,
            horizontalAccuracyM: horizontalAccuracyM
        )
    }

    public mutating func deletePoints(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard points.indices.contains(index) else {
                continue
            }
            points.remove(at: index)
        }
    }

    public mutating func insertMidpoint(after index: Int) {
        guard points.indices.contains(index), index < points.count - 1 else {
            return
        }

        let lhs = points[index]
        let rhs = points[index + 1]
        let insertedPoint = RecordedTrackPoint(
            latitude: (lhs.latitude + rhs.latitude) / 2,
            longitude: (lhs.longitude + rhs.longitude) / 2,
            timestamp: midpointDate(between: lhs.timestamp, and: rhs.timestamp),
            horizontalAccuracyM: max((lhs.horizontalAccuracyM + rhs.horizontalAccuracyM) / 2, 0)
        )
        points.insert(insertedPoint, at: index + 1)
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func midpointDate(between lhs: Date, and rhs: Date) -> Date {
        let interval = rhs.timeIntervalSince(lhs)
        return lhs.addingTimeInterval(interval / 2)
    }

    private func totalDistance(points: [RecordedTrackPoint]) -> Double {
        guard points.count >= 2 else {
            return 0
        }

        var total = 0.0
        for pair in zip(points, points.dropFirst()) {
            let a = LocationCoordinate2D(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = LocationCoordinate2D(latitude: pair.1.latitude, longitude: pair.1.longitude)
            total += a.distance(to: b)
        }
        return total
    }
}
