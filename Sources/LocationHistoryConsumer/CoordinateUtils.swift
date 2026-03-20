import Foundation

/// A platform-independent 2D coordinate.
public struct LocationCoordinate2D: Equatable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Returns the Haversine distance in meters between this coordinate and another.
    public func distance(to other: LocationCoordinate2D) -> Double {
        let earthRadiusM = 6_371_000.0
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }
}

public enum ExportUtils {
    public static func trackTitle(date: String, activityType: String?, index: Int) -> String {
        let typePart = activityType.map { " – \($0.capitalized)" } ?? ""
        let indexSuffix = index > 0 ? " (\(index + 1))" : ""
        return "\(date)\(typePart)\(indexSuffix)"
    }
    
    public static func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
