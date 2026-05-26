import XCTest
@testable import LocationHistoryConsumerAppSupport

/// Recording stub provider — counts how often the cache reaches through. Used
/// by the throttle tests to assert the cache short-circuits.
private final class RecordingProvider: WeatherDataProvider, @unchecked Sendable {
    var callCount: Int = 0
    var snapshot: WeatherSnapshot

    init(snapshot: WeatherSnapshot = WeatherSnapshot(
        temperatureC: 12.0,
        condition: "Bewölkt",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )) {
        self.snapshot = snapshot
    }

    func currentWeather(at coordinate: AppWeatherCoordinate) async throws -> WeatherSnapshot {
        callCount += 1
        return snapshot
    }
}

final class AppWeatherCacheManagerTests: XCTestCase {

    func testCacheMissFetchesFromProvider() async throws {
        let provider = RecordingProvider()
        let manager = WeatherCacheManager()
        let coord = AppWeatherCoordinate(latitude: 52.5, longitude: 13.4)

        let result = try await manager.snapshot(at: coord, provider: provider)

        XCTAssertEqual(result, provider.snapshot)
        XCTAssertEqual(provider.callCount, 1)
        let count = await manager._debug_cacheCount()
        XCTAssertEqual(count, 1)
    }

    func testCacheHitWithinTtlSkipsProvider() async throws {
        let provider = RecordingProvider()
        let manager = WeatherCacheManager()
        let coord = AppWeatherCoordinate(latitude: 52.5, longitude: 13.4)

        _ = try await manager.snapshot(at: coord, provider: provider)
        _ = try await manager.snapshot(at: coord, provider: provider)
        _ = try await manager.snapshot(at: coord, provider: provider)

        XCTAssertEqual(provider.callCount, 1, "Cache must coalesce repeated reads inside TTL")
    }

    func testNearbyCoordinatesShareBin() async throws {
        let provider = RecordingProvider()
        let manager = WeatherCacheManager()
        let a = AppWeatherCoordinate(latitude: 52.5000, longitude: 13.4000)
        let b = AppWeatherCoordinate(latitude: 52.5012, longitude: 13.4008) // <0.01° apart

        _ = try await manager.snapshot(at: a, provider: provider)
        _ = try await manager.snapshot(at: b, provider: provider)

        XCTAssertEqual(provider.callCount, 1)
    }

    func testStaleEntryTriggersRefetch() async throws {
        let provider = RecordingProvider()
        // Use a tiny TTL + controllable clock so we don't sleep in the test.
        var current = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = WeatherCacheManager(maxAge: 60, clock: { current })
        let coord = AppWeatherCoordinate(latitude: 1.0, longitude: 2.0)

        _ = try await manager.snapshot(at: coord, provider: provider)
        current = current.addingTimeInterval(120) // > TTL
        _ = try await manager.snapshot(at: coord, provider: provider)

        XCTAssertEqual(provider.callCount, 2)
    }

    func testResetClearsCache() async throws {
        let provider = RecordingProvider()
        let manager = WeatherCacheManager()
        let coord = AppWeatherCoordinate(latitude: 1, longitude: 2)

        _ = try await manager.snapshot(at: coord, provider: provider)
        await manager.reset()
        _ = try await manager.snapshot(at: coord, provider: provider)

        XCTAssertEqual(provider.callCount, 2)
    }

    func testStaticProviderRoundTrip() async throws {
        let snapshot = WeatherSnapshot(temperatureC: 7.5, condition: "Sonnig", timestamp: Date())
        let provider = StaticWeatherProvider(snapshot: snapshot)
        let manager = WeatherCacheManager()
        let coord = AppWeatherCoordinate(latitude: 48.137, longitude: 11.575)

        let first = try await manager.snapshot(at: coord, provider: provider)
        let second = try await manager.snapshot(at: coord, provider: provider)

        XCTAssertEqual(first, snapshot)
        XCTAssertEqual(second, snapshot)
    }

    func testCoordinateKeyRoundsAsExpected() {
        let a = WeatherCacheManager.CoordinateKey(latitude: 52.5000, longitude: 13.4000)
        let b = WeatherCacheManager.CoordinateKey(latitude: 52.5012, longitude: 13.3992)
        XCTAssertEqual(a, b)
    }
}
