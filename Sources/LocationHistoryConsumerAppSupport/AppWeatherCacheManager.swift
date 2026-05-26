// AppWeatherCacheManager
//
// Thin throttled cache in front of any `WeatherDataProvider`. WeatherKit is a
// paid API and Apple's documentation recommends batching requests; the live
// tracking view in particular may try to refresh while the user pans across
// the map. We coalesce calls into ~0.01° coordinate bins (~1.1 km at the
// equator) and never refresh a bin more often than every 10 minutes.
//
// The manager is intentionally an `actor` so we can be hit from concurrent
// SwiftUI `.task` modifiers without races on the cache dictionary.

import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

public actor WeatherCacheManager {

    /// Coarse cache key — rounded to ~0.01° so nearby reads share a snapshot.
    public struct CoordinateKey: Hashable, Sendable {
        public let lat: Int
        public let lon: Int

        public init(latitude: Double, longitude: Double, precision: Double = 0.01) {
            // Avoid division by zero; default precision is 0.01° per task.
            let p = precision == 0 ? 0.01 : precision
            self.lat = Int((latitude / p).rounded())
            self.lon = Int((longitude / p).rounded())
        }
    }

    public struct Entry: Sendable, Equatable {
        public let snapshot: WeatherSnapshot
        public let fetchedAt: Date

        public init(snapshot: WeatherSnapshot, fetchedAt: Date) {
            self.snapshot = snapshot
            self.fetchedAt = fetchedAt
        }
    }

    public static let defaultMaxAge: TimeInterval = 10 * 60   // 10 minutes
    public static let defaultPrecision: Double = 0.01

    private var cache: [CoordinateKey: Entry] = [:]
    private let maxAge: TimeInterval
    private let precision: Double
    private let clock: @Sendable () -> Date

    public init(
        maxAge: TimeInterval = WeatherCacheManager.defaultMaxAge,
        precision: Double = WeatherCacheManager.defaultPrecision,
        clock: @Sendable @escaping () -> Date = { Date() }
    ) {
        self.maxAge = maxAge
        self.precision = precision
        self.clock = clock
    }

    public func snapshot(
        at coordinate: AppWeatherCoordinate,
        provider: WeatherDataProvider
    ) async throws -> WeatherSnapshot {
        let key = CoordinateKey(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: precision
        )
        let now = clock()
        if let entry = cache[key], now.timeIntervalSince(entry.fetchedAt) < maxAge {
            return entry.snapshot
        }
        let fresh = try await provider.currentWeather(at: coordinate)
        cache[key] = Entry(snapshot: fresh, fetchedAt: now)
        return fresh
    }

    /// Drops every cached snapshot. Useful for previews and unit tests.
    public func reset() {
        cache.removeAll()
    }

    // MARK: - Test introspection

    public func _debug_cacheCount() -> Int { cache.count }
    public func _debug_entry(for coordinate: AppWeatherCoordinate) -> Entry? {
        cache[CoordinateKey(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            precision: precision
        )]
    }
}

// MARK: - SwiftUI bridge

#if canImport(Combine)
import Combine

/// Lightweight `ObservableObject` wrapper so the actor instance survives
/// SwiftUI view rebuilds via `@StateObject`. The wrapper itself emits no
/// updates — UI state lives in `@State` next to the view that owns it.
@MainActor
public final class AppWeatherCacheManagerBox: ObservableObject {
    public let manager: WeatherCacheManager

    public init(manager: WeatherCacheManager = WeatherCacheManager()) {
        self.manager = manager
    }
}
#endif
