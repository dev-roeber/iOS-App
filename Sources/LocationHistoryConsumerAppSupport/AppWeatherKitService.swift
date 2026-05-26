// AppWeatherKitService
//
// Service-layer scaffold for the in-app weather panel. This file deliberately
// stays UI-free: we only expose a protocol + DTO, the iOS WeatherKit-backed
// implementation behind `canImport(WeatherKit)` and a deterministic Linux/
// test stub. Wiring this provider into Live / DayDetail / Insights / Export
// views is intentionally out of scope for this change — that work is
// scheduled for a follow-up PR.
//
// WeatherKit setup note:
// - WeatherKit requires the **WeatherKit capability** to be enabled in the
//   Xcode project and matching App Service in App Store Connect.
// - The Apple Developer account must have an active Apple Developer Program
//   membership; the capability is not available on free accounts.
// - There is a free request quota (≈ 500k calls / month / team); the service
//   throws on exhaustion.
// Configuration of the capability + entitlement is **not** part of this
// PR — it must be done in the Xcode project setup before the iOS
// implementation is exercised at runtime.

import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Coordinate shim usable on every platform — on Apple we re-export
/// `CLLocationCoordinate2D`, on Linux we provide a value-type stand-in so
/// the provider protocol still compiles for the test stub.
#if canImport(CoreLocation)
public typealias AppWeatherCoordinate = CLLocationCoordinate2D
#else
public struct AppWeatherCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
#endif

/// Lightweight DTO returned by every weather provider. Intentionally tiny —
/// future fields (windSpeed, humidity, UVIndex, …) will land in follow-up
/// PRs together with their UI surfaces.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Temperature in degrees Celsius.
    public let temperatureC: Double
    /// Free-form, localised condition label (e.g. "Sonnig", "Bewölkt").
    public let condition: String
    /// Sample timestamp.
    public let timestamp: Date

    public init(temperatureC: Double, condition: String, timestamp: Date) {
        self.temperatureC = temperatureC
        self.condition = condition
        self.timestamp = timestamp
    }
}

/// Protocol every weather provider must conform to. Async-throws so the iOS
/// WeatherKit call can be awaited directly.
public protocol WeatherDataProvider: Sendable {
    func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot
}

/// Errors surfaced to the caller. Stable across providers so call sites can
/// switch on a single enum without leaking WeatherKit internals.
public enum AppWeatherError: Error, Sendable, Equatable {
    case unavailable
    case requestFailed(String)
}

// MARK: - Deterministic stub (Linux + tests)

/// Returns a fixed snapshot — useful for previews, snapshot tests and Linux
/// CI where WeatherKit cannot be linked.
public final class StaticWeatherProvider: WeatherDataProvider, @unchecked Sendable {
    private let snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
    }

    public convenience init() {
        self.init(snapshot: WeatherSnapshot(
            temperatureC: 18.0,
            condition: "Bewölkt",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))
    }

    public func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot {
        snapshot
    }
}

// MARK: - WeatherKit-backed implementation (iOS only)

#if canImport(WeatherKit) && os(iOS)
import WeatherKit

/// Production WeatherKit implementation. Requires the WeatherKit entitlement
/// on the host app; see file-level note above. Calls the shared
/// `WeatherService` for a single-shot current-conditions request and maps
/// the result onto our compact `WeatherSnapshot` DTO.
@available(iOS 16.0, *)
public final class WeatherKitService: WeatherDataProvider, @unchecked Sendable {
    public init() {}

    public func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let tempC = current.temperature.converted(to: .celsius).value
            let condition = current.condition.description
            return WeatherSnapshot(
                temperatureC: tempC,
                condition: condition,
                timestamp: current.date
            )
        } catch {
            throw AppWeatherError.requestFailed(String(describing: error))
        }
    }
}
#endif
