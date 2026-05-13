import Foundation

/// Foundation-only coordinate validity check. Shared between Linux-buildable
/// data preparation (`ExportPreviewDataBuilder`, `AppHeatmapModel` collect
/// loop, Overview candidate scan) and the SwiftUI/MapKit-gated
/// `MapCoordinateGuard` in `MapTrackStyling.swift`. Keeping the check itself
/// platform-neutral lets the Foundation layer reject NaN/Inf/sentinel values
/// before they ever reach MapKit, and lets the same logic be unit-tested on
/// Linux without the SwiftUI guard.
///
/// Rejects: NaN, ±Inf, lat outside ±90°, lon outside ±180°, and Apple's
/// `kCLLocationCoordinate2DInvalid` (lat = lon = -180) sentinel.
public enum CoordinateValidity {
    @inlinable
    public static func isValid(latitude lat: Double, longitude lon: Double) -> Bool {
        guard lat.isFinite, lon.isFinite else { return false }
        guard lat >= -90, lat <= 90 else { return false }
        guard lon >= -180, lon <= 180 else { return false }
        // Apple's invalid sentinel
        if lat == -180 && lon == -180 { return false }
        return true
    }
}
