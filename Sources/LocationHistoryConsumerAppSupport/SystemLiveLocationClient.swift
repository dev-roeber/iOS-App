import Foundation

@MainActor
public protocol LiveLocationClient: AnyObject {
    var authorization: LiveLocationAuthorization { get }
    var onAuthorizationChange: ((LiveLocationAuthorization) -> Void)? { get set }
    var onLocationSamples: (([LiveLocationSample]) -> Void)? { get set }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func setBackgroundTrackingEnabled(_ enabled: Bool)
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

#if canImport(CoreLocation)
import CoreLocation

@MainActor
public final class SystemLiveLocationClient: NSObject, LiveLocationClient {
    public var onAuthorizationChange: ((LiveLocationAuthorization) -> Void)?
    public var onLocationSamples: (([LiveLocationSample]) -> Void)?

    private let manager: CLLocationManager

    public override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
    }

    public var authorization: LiveLocationAuthorization {
        switch manager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .denied
        }
    }

    public func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func setBackgroundTrackingEnabled(_ enabled: Bool) {
        manager.allowsBackgroundLocationUpdates = enabled
        manager.pausesLocationUpdatesAutomatically = !enabled
        #if os(iOS)
        manager.showsBackgroundLocationIndicator = enabled
        #endif
    }

    public func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    public func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}

extension SystemLiveLocationClient: @MainActor CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(authorization)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map { location -> LiveLocationSample in
            // Train 9.2: forward altitude only when CoreLocation reports a
            // positive verticalAccuracy. Negative values (typically `-1.0`)
            // mean the device could not determine altitude reliably — we
            // drop both fields so downstream consumers never see a stale
            // or invented elevation.
            let altitudeM: Double?
            let verticalAccuracyM: Double?
            if LocationElevationFormatter.isValidAltitude(
                altitudeM: location.altitude,
                verticalAccuracyM: location.verticalAccuracy
            ) {
                altitudeM = location.altitude
                verticalAccuracyM = location.verticalAccuracy
            } else {
                altitudeM = nil
                verticalAccuracyM = nil
            }
            return LiveLocationSample(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                horizontalAccuracyM: location.horizontalAccuracy,
                altitudeM: altitudeM,
                verticalAccuracyM: verticalAccuracyM
            )
        }
        onLocationSamples?(samples)
    }
}
#endif
