import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppWeatherKitServiceTests: XCTestCase {

    func testStaticProviderReturnsConfiguredSnapshot() async throws {
        let snapshot = WeatherSnapshot(
            temperatureC: 22.5,
            condition: "Sonnig",
            timestamp: Date(timeIntervalSince1970: 1_700_000_500)
        )
        let provider = StaticWeatherProvider(snapshot: snapshot)
        let coord = AppWeatherCoordinate(latitude: 52.5, longitude: 13.4)
        let result = try await provider.currentWeather(at: coord)
        XCTAssertEqual(result, snapshot)
    }

    func testStaticProviderDefaultSnapshotIsStable() async throws {
        let provider = StaticWeatherProvider()
        let coord = AppWeatherCoordinate(latitude: 0, longitude: 0)
        let result = try await provider.currentWeather(at: coord)
        XCTAssertEqual(result.temperatureC, 18.0)
        XCTAssertEqual(result.condition, "Bewölkt")
    }

    // WeatherKit production service is only available on iOS with the
    // WeatherKit entitlement. On Linux CI the module cannot be imported so
    // we deliberately skip the live test here; coverage of the iOS branch
    // happens in the device-build smoke tests once the entitlement is wired
    // up in Xcode.
    func testWeatherKitServiceSkippedOnLinux() {
        #if canImport(WeatherKit) && os(iOS)
        // Compile-only smoke: the symbol exists when the entitlement target
        // is built. We do not invoke the network call from the unit-test
        // suite.
        if #available(iOS 16.0, *) {
            _ = WeatherKitService.self
        }
        #endif
        XCTAssertTrue(true)
    }

    func testWeatherErrorKeepsDiagnosticDetailsForSettings() {
        let error = AppWeatherError.requestFailed("WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors Code=2 401 auth failed")

        XCTAssertTrue(error.diagnosticDescription.contains("WeatherDaemon"))
        XCTAssertTrue(error.userFacingGermanDiagnostic.contains("Entitlement"))
        XCTAssertTrue(error.userFacingGermanDiagnostic.contains("Provisioning Profile"))
        XCTAssertTrue(error.userFacingGermanDiagnostic.contains("Developer-Portal"))
        XCTAssertTrue(error.userFacingGermanDiagnostic.contains("401"))
    }

    func testWeatherErrorRedactsTokenValuesInUserFacingDiagnostic() {
        let error = AppWeatherError.requestFailed("401 Authorization: Bearer abc123 jwt=secret token=other")
        let diagnostic = error.userFacingGermanDiagnostic

        XCTAssertTrue(diagnostic.contains("401"))
        XCTAssertTrue(diagnostic.contains("Bearer [redacted]"))
        XCTAssertTrue(diagnostic.contains("jwt=[redacted]"))
        XCTAssertTrue(diagnostic.contains("token=[redacted]"))
        XCTAssertFalse(diagnostic.contains("abc123"))
        XCTAssertFalse(diagnostic.contains("secret"))
        XCTAssertFalse(diagnostic.contains("other"))
    }

    func testNSErrorDiagnosticIncludesDomainCodeAndUnderlyingError() {
        let underlying = NSError(domain: "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors", code: 2)
        let error = NSError(
            domain: "WeatherKit.WeatherService",
            code: 401,
            userInfo: [
                NSLocalizedDescriptionKey: "Authentication failed",
                NSUnderlyingErrorKey: underlying
            ]
        )

        let message = AppWeatherDiagnostics.requestFailedMessage(from: error)

        XCTAssertTrue(message.contains("WeatherKit.WeatherService"))
        XCTAssertTrue(message.contains("code=401"))
        XCTAssertTrue(message.contains("WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors"))
        XCTAssertTrue(message.contains("code=2"))
    }
}
