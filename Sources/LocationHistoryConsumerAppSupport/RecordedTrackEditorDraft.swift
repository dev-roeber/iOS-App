import Foundation
import LocationHistoryConsumer

struct RecordedTrackEditorDraft: Equatable {
    let originalTrack: RecordedTrack
    var points: [RecordedTrackPoint]

    private let calendar: Calendar

    init(track: RecordedTrack, calendar: Calendar = .autoupdatingCurrent) {
        self.originalTrack = track
        self.points = track.points
        self.calendar = calendar
    }

    var isModified: Bool {
        points != originalTrack.points
    }

    var validationMessage: String? {
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

    var distanceM: Double {
        totalDistance(points: points)
    }

    var pointCount: Int {
        points.count
    }

    var dayKey: String {
        guard let first = points.first else {
            return originalTrack.dayKey
        }
        return dayFormatter.string(from: first.timestamp)
    }

    var startedAt: Date {
        points.first?.timestamp ?? originalTrack.startedAt
    }

    var endedAt: Date {
        points.last?.timestamp ?? originalTrack.endedAt
    }

    var savedTrack: RecordedTrack? {
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

    mutating func reset() {
        points = originalTrack.points
    }

    mutating func updateCoordinate(
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

    mutating func updateAccuracy(at index: Int, horizontalAccuracyM: Double) {
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

    mutating func deletePoints(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard points.indices.contains(index) else {
                continue
            }
            points.remove(at: index)
        }
    }

    mutating func insertMidpoint(after index: Int) {
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
