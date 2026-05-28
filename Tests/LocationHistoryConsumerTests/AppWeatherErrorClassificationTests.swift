import XCTest
@testable import LocationHistoryConsumerAppSupport

final class AppWeatherErrorClassificationTests: XCTestCase {

    // MARK: - isPermanent

    func test_notProvisioned_isPermanent() {
        XCTAssertTrue(AppWeatherError.notProvisioned("test").isPermanent)
    }

    func test_unavailable_isPermanent() {
        XCTAssertTrue(AppWeatherError.unavailable.isPermanent)
    }

    func test_requestFailed_isNotPermanent() {
        XCTAssertFalse(AppWeatherError.requestFailed("transient").isPermanent)
    }

    // MARK: - Domain-based classification

    func test_classify_wdsjwtAuthenticator_domain_isNotProvisioned() {
        let err = NSError(
            domain: "WDSJWTAuthenticatorServiceListener.Errors",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unauthorized"]
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .notProvisioned = classified {
            // ok
        } else {
            XCTFail("Expected .notProvisioned, got \(classified)")
        }
    }

    func test_classify_weatherKitAuthservice_domain_isNotProvisioned() {
        let err = NSError(
            domain: "com.apple.weatherkit.authservice",
            code: 1,
            userInfo: nil
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .notProvisioned = classified {
            // ok
        } else {
            XCTFail("Expected .notProvisioned, got \(classified)")
        }
    }

    func test_classify_weatherDaemonAuthorization_domain_isNotProvisioned() {
        let err = NSError(
            domain: "WeatherDaemon.WeatherAuthorization",
            code: 0,
            userInfo: nil
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .notProvisioned = classified {
            // ok
        } else {
            XCTFail("Expected .notProvisioned, got \(classified)")
        }
    }

    // MARK: - Code/Debug-text-based classification

    func test_classify_wdsjwt_code2_inDebugText_isNotProvisioned() {
        // Simuliert die Apple-Variante, bei der die Domain anders heisst,
        // aber die Listener-Domain als Suffix im Debug-Text auftaucht.
        let err = NSError(
            domain: "NSCocoaErrorDomain",
            code: 2,
            userInfo: [NSDebugDescriptionErrorKey: "WDSJWTAuthenticatorServiceListener.Errors code=2"]
        )
        XCTAssertTrue(
            AppWeatherDiagnostics.isNotProvisionedError(
                domain: "NSCocoaErrorDomain",
                code: 2,
                debug: "WDSJWTAuthenticatorServiceListener.Errors code=2"
            )
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .notProvisioned = classified {
            // ok
        } else {
            XCTFail("Expected .notProvisioned, got \(classified)")
        }
    }

    func test_classify_http401_inWeatherContext_isNotProvisioned() {
        let err = NSError(
            domain: "NSURLErrorDomain",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Weather backend rejected request"]
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .notProvisioned = classified {
            // ok
        } else {
            XCTFail("Expected .notProvisioned for HTTP 401 in weather context, got \(classified)")
        }
    }

    // MARK: - Negative cases

    func test_classify_transientNetworkError_isRequestFailed() {
        // Klassischer Netzfehler — DOM hat nichts mit WeatherKit-Auth zu tun.
        let err = NSError(
            domain: "NSURLErrorDomain",
            code: -1009, // notConnectedToInternet
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .requestFailed = classified {
            // ok
        } else {
            XCTFail("Expected .requestFailed, got \(classified)")
        }
        XCTAssertFalse(classified.isPermanent)
    }

    func test_classify_quotaExceeded_isRequestFailed() {
        // Quota-Fehler sind transient (Backoff-/Tag-Reset-faehig) und sollen
        // NICHT als notProvisioned klassifiziert werden.
        let err = NSError(
            domain: "WeatherDaemon.WeatherServiceError",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Quota exhausted"]
        )
        let classified = AppWeatherDiagnostics.classify(err)
        if case .requestFailed = classified {
            // ok — quota braucht Retry mit Backoff, nicht permanent
        } else {
            XCTFail("Expected .requestFailed for quota, got \(classified)")
        }
    }

    // MARK: - User-facing diagnostic

    func test_notProvisioned_germanTitle() {
        XCTAssertEqual(
            AppWeatherError.notProvisioned("x").userFacingGermanTitle,
            "Wetter nicht freigeschaltet"
        )
    }

    func test_notProvisioned_diagnosticMentionsNoRetry() {
        let diag = AppWeatherError.notProvisioned("WDSJWTAuthenticatorServiceListener.Errors code=2")
            .userFacingGermanDiagnostic
        XCTAssertTrue(diag.contains("Apple Developer Portal"))
        XCTAssertTrue(diag.contains("Wiederholungsversuche sind deaktiviert"))
    }

    func test_notProvisioned_diagnostic_redactsAuthorizationBearer() {
        let raw = "Authorization: Bearer eyJabc123secrettoken"
        let diag = AppWeatherError.notProvisioned(raw).userFacingGermanDiagnostic
        XCTAssertFalse(diag.contains("eyJabc123secrettoken"))
        XCTAssertTrue(diag.contains("[redacted]"))
    }

    // MARK: - Idempotency

    func test_classify_idempotent_onAppWeatherError() {
        let original = AppWeatherError.notProvisioned("foo")
        let classified = AppWeatherDiagnostics.classify(original)
        XCTAssertEqual(classified, original)
    }
}
