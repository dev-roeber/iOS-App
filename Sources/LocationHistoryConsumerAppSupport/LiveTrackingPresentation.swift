import Foundation
import LocationHistoryConsumer

struct LiveTrackingMetricSnapshot: Equatable {
    let totalDistanceM: Double
    let currentSpeedKMH: Double?
    let lastSegmentDistanceM: Double?
    let lastSampleDate: Date?

    static let empty = LiveTrackingMetricSnapshot(
        totalDistanceM: 0,
        currentSpeedKMH: nil,
        lastSegmentDistanceM: nil,
        lastSampleDate: nil
    )
}

enum LiveTrackingPresentation {

    // MARK: - GPS Status

    /// Returns "GPS Good" when accuracy is below 30 m, otherwise "GPS Weak".
    static func gpsStatusLabel(accuracyM: Double?) -> String {
        guard let acc = accuracyM, acc >= 0 else { return "GPS Weak" }
        return acc < 30 ? "GPS Good" : "GPS Weak"
    }

    // MARK: - Upload Section Visibility

    /// Returns true when the upload section should be shown.
    static func uploadSectionVisible(
        sendsToServer: Bool,
        pendingCount: Int,
        statusMessage: String?
    ) -> Bool {
        sendsToServer || pendingCount > 0 || statusMessage != nil
    }

    // MARK: - Metrics

    static func metrics(
        points: [RecordedTrackPoint],
        currentLocation: LiveLocationSample?
    ) -> LiveTrackingMetricSnapshot {
        let totalDistanceM = totalDistance(points: points)
        let currentSpeedKMH = currentSpeed(points: points)
        let lastSegmentDistanceM = segmentDistance(points: points.suffix(2))
        let lastSampleDate = latestSampleDate(points: points, currentLocation: currentLocation)

        return LiveTrackingMetricSnapshot(
            totalDistanceM: totalDistanceM,
            currentSpeedKMH: currentSpeedKMH,
            lastSegmentDistanceM: lastSegmentDistanceM,
            lastSampleDate: lastSampleDate
        )
    }

    private static func totalDistance(points: [RecordedTrackPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for index in 1..<points.count {
            total += segmentDistance(points: [points[index - 1], points[index]]) ?? 0
        }
        return total
    }

    private static func currentSpeed(points: [RecordedTrackPoint]) -> Double? {
        guard points.count >= 2 else { return nil }
        let latestPoints = Array(points.suffix(2))
        guard let distanceM = segmentDistance(points: latestPoints) else {
            return nil
        }
        let duration = latestPoints[1].timestamp.timeIntervalSince(latestPoints[0].timestamp)
        guard duration > 0 else { return nil }
        return (distanceM / duration) * 3.6
    }

    private static func latestSampleDate(
        points: [RecordedTrackPoint],
        currentLocation: LiveLocationSample?
    ) -> Date? {
        switch (points.last?.timestamp, currentLocation?.timestamp) {
        case let (pointDate?, currentDate?):
            return pointDate >= currentDate ? pointDate : currentDate
        case let (pointDate?, nil):
            return pointDate
        case let (nil, currentDate?):
            return currentDate
        case (nil, nil):
            return nil
        }
    }

    private static func segmentDistance<S: Sequence>(points: S) -> Double? where S.Element == RecordedTrackPoint {
        let segment = Array(points)
        guard segment.count == 2 else {
            return nil
        }
        let a = LocationCoordinate2D(latitude: segment[0].latitude, longitude: segment[0].longitude)
        let b = LocationCoordinate2D(latitude: segment[1].latitude, longitude: segment[1].longitude)
        return a.distance(to: b)
    }
}
